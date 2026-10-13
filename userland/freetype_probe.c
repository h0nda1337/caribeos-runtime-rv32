/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Genuine FreeType rasterizer dependency gates, not a replacement Syllable Font server.
 */
#define _GNU_SOURCE
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MODULE_H
#include FT_FONT_FORMATS_H
#include FT_SYNTHESIS_H
#include <atheos/areas.h>
#include <uapi/caribe_area.h>
#include <uapi/caribe_graphics.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    printf("[freetype] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
#define WIDTH 800U
#define HEIGHT 600U
#define BACKGROUND 0x182129U
#define FONT_DIR "/usr/share/fonts/vera/"
#define FONT_LIMIT (1024U * 1024U)

struct allocation_stats { size_t bytes, blocks, peak, attempts, faults; long fail_after; };
union allocation_header { max_align_t alignment; size_t bytes; };
static struct allocation_stats memory_stats;
static struct FT_MemoryRec_ memory;
static FT_Library library;

static void *font_alloc(FT_Memory mem, long size)
{
    struct allocation_stats *stats = mem->user;
    union allocation_header *header;
    if (size <= 0 || (size_t)size > FONT_LIMIT * 8U) return NULL;
    if (stats->fail_after >= 0 && stats->attempts++ >= (size_t)stats->fail_after) {
        stats->faults++;
        return NULL;
    }
    header = malloc(sizeof(*header) + (size_t)size);
    if (!header) return NULL;
    header->bytes = (size_t)size;
    stats->bytes += (size_t)size; stats->blocks++;
    if (stats->bytes > stats->peak) stats->peak = stats->bytes;
    return header + 1;
}
static void font_free(FT_Memory mem, void *block)
{
    struct allocation_stats *stats = mem->user;
    union allocation_header *header;
    if (!block) return;
    header = (union allocation_header *)block - 1;
    stats->bytes -= header->bytes; stats->blocks--;
    free(header);
}
static void *font_realloc(FT_Memory mem, long old_size, long size, void *block)
{
    void *fresh;
    size_t copy;
    (void)old_size;
    if (!size) { font_free(mem, block); return NULL; }
    fresh = font_alloc(mem, size);
    if (!fresh) return NULL;
    if (block) {
        copy = ((union allocation_header *)block - 1)->bytes;
        if (copy > (size_t)size) copy = (size_t)size;
        memcpy(fresh, block, copy);
        font_free(mem, block);
    }
    return fresh;
}
static int engine_start(void)
{
    memset(&memory_stats, 0, sizeof(memory_stats));
    memory_stats.fail_after = -1;
    memory.user = &memory_stats;
    memory.alloc = font_alloc; memory.free = font_free; memory.realloc = font_realloc;
    CHECK(FT_New_Library(&memory, &library) == 0);
    FT_Add_Default_Modules(library);
    return 0;
}
static int engine_stop(void)
{
    CHECK(FT_Done_Library(library) == 0);
    CHECK(memory_stats.bytes == 0 && memory_stats.blocks == 0);
    return 0;
}
static int load_font(const char *name, unsigned char **data, size_t *size)
{
    char path[128]; FILE *file; long length;
    CHECK(snprintf(path, sizeof(path), FONT_DIR "%s", name) < (int)sizeof(path));
    file = fopen(path, "rb"); CHECK(file);
    CHECK(fseek(file, 0, SEEK_END) == 0);
    length = ftell(file); CHECK(length > 0 && length <= (long)FONT_LIMIT);
    CHECK(fseek(file, 0, SEEK_SET) == 0);
    *data = malloc((size_t)length); CHECK(*data);
    CHECK(fread(*data, 1, (size_t)length, file) == (size_t)length && fclose(file) == 0);
    *size = (size_t)length;
    return 0;
}
static uint32_t pixel_hash(const uint32_t *pixels)
{
    uint32_t hash = 2166136261U;
    unsigned i;
    for (i = 0; i < WIDTH * HEIGHT; i++) { hash ^= pixels[i]; hash *= 16777619U; }
    return hash;
}
static unsigned blend(unsigned back, unsigned front, unsigned coverage)
{
    return (back * (255U - coverage) + front * coverage + 127U) / 255U;
}
static int draw_text(FT_Face face, uint32_t *pixels, int x, int baseline,
                     unsigned height, const char *text, uint32_t color, int mono)
{
    FT_UInt previous = 0;
    CHECK(FT_Set_Pixel_Sizes(face, 0, height) == 0);
    while (*text) {
        FT_UInt glyph = FT_Get_Char_Index(face, (unsigned char)*text++);
        FT_Bitmap *bitmap;
        unsigned row, col;
        if (previous && glyph && FT_HAS_KERNING(face)) {
            FT_Vector delta;
            CHECK(FT_Get_Kerning(face, previous, glyph, FT_KERNING_DEFAULT, &delta) == 0);
            x += (int)(delta.x >> 6);
        }
        CHECK(glyph && FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT) == 0);
        CHECK(FT_Render_Glyph(face->glyph, mono ? FT_RENDER_MODE_MONO : FT_RENDER_MODE_NORMAL) == 0);
        bitmap = &face->glyph->bitmap;
        CHECK(bitmap->pixel_mode == (mono ? FT_PIXEL_MODE_MONO : FT_PIXEL_MODE_GRAY));
        for (row = 0; row < bitmap->rows; row++) {
            int stride = bitmap->pitch;
            const unsigned char *source = bitmap->buffer +
                (stride >= 0 ? row * (unsigned)stride : (bitmap->rows - 1U - row) * (unsigned)-stride);
            for (col = 0; col < bitmap->width; col++) {
                unsigned alpha = mono ? ((source[col / 8] & (0x80U >> (col % 8))) ? 255U : 0U) : source[col];
                int dx = x + face->glyph->bitmap_left + (int)col;
                int dy = baseline - face->glyph->bitmap_top + (int)row;
                uint32_t back;
                if (!alpha || dx < 0 || dx >= (int)WIDTH || dy < 0 || dy >= (int)HEIGHT) continue;
                back = pixels[(unsigned)dy * WIDTH + (unsigned)dx];
                pixels[(unsigned)dy * WIDTH + (unsigned)dx] =
                    (blend((back >> 16) & 255U, (color >> 16) & 255U, alpha) << 16) |
                    (blend((back >> 8) & 255U, (color >> 8) & 255U, alpha) << 8) |
                    blend(back & 255U, color & 255U, alpha);
            }
        }
        x += (int)(face->glyph->advance.x >> 6);
        previous = glyph;
    }
    return 0;
}
static int render_frame(uint32_t *pixels)
{
    unsigned char *regular, *bold, *mono; size_t rs, bs, ms;
    FT_Face a, b, c; unsigned i;
    CHECK(engine_start() == 0);
    CHECK(load_font("Vera.ttf", &regular, &rs) == 0 && load_font("VeraBd.ttf", &bold, &bs) == 0 &&
          load_font("VeraMono.ttf", &mono, &ms) == 0);
    CHECK(FT_New_Memory_Face(library, regular, (FT_Long)rs, 0, &a) == 0);
    CHECK(FT_New_Memory_Face(library, bold, (FT_Long)bs, 0, &b) == 0);
    CHECK(FT_New_Memory_Face(library, mono, (FT_Long)ms, 0, &c) == 0);
    for (i = 0; i < WIDTH * HEIGHT; i++) pixels[i] = BACKGROUND;
    for (i = 96 * WIDTH; i < 98 * WIDTH; i++) pixels[i] = 0x41baa9U;
    CHECK(draw_text(b, pixels, 36, 60, 30, "CaribeOS / Syllable", 0xf5f7faU, 0) == 0);
    CHECK(draw_text(a, pixels, 36, 133, 18, "FreeType 2.15.0 | RV32IMACSU | native XNU", 0x54d5c0U, 0) == 0);
    CHECK(draw_text(a, pixels, 36, 180, 12, "Bitstream Vera Sans 12: Aa Bb Cc 0123456789", 0xffffffU, 0) == 0);
    CHECK(draw_text(a, pixels, 36, 224, 18, "Bitstream Vera Sans 18: Aa Bb Cc", 0xffffffU, 0) == 0);
    CHECK(draw_text(a, pixels, 36, 277, 24, "Bitstream Vera Sans 24", 0xffffffU, 0) == 0);
    CHECK(draw_text(b, pixels, 36, 337, 30, "Vera Bold / AV To Wa", 0xf0c76bU, 0) == 0);
    CHECK(draw_text(c, pixels, 36, 404, 18, "Vera Mono: 0x68000000  RV32 musl", 0xb6c7eeU, 0) == 0);
    CHECK(draw_text(a, pixels, 36, 467, 20, "Monochrome raster: Aa Bb 0123456789", 0xffffffU, 1) == 0);
    CHECK(draw_text(a, pixels, 36, 548, 14, "Independent exec -> shared Sv32 pages -> virtio-gpu", 0x54d5c0U, 0) == 0);
    CHECK(FT_Done_Face(a) == 0 && FT_Done_Face(b) == 0 && FT_Done_Face(c) == 0);
    free(regular); free(bold); free(mono);
    CHECK(engine_stop() == 0);
    return 0;
}
static int dependency_gates(char last)
{
    unsigned char *data; size_t size, baseline_bytes, baseline_blocks;
    FT_Face face; FT_Int major, minor, patch; FT_UInt glyph;
    FT_Vector kern; unsigned i; unsigned gray = 0, solid = 0;
    CHECK(engine_start() == 0);
    FT_Library_Version(library, &major, &minor, &patch);
    CHECK(major == 2 && minor == 15 && patch == 0);
    CHECK(load_font("Vera.ttf", &data, &size) == 0);
    CHECK(FT_New_Memory_Face(library, data, (FT_Long)size, 0, &face) == 0);
    CHECK(!strcmp(FT_Get_Font_Format(face), "TrueType") && face->num_glyphs > 200 &&
          face->units_per_EM == 2048 && FT_IS_SCALABLE(face) && FT_HAS_KERNING(face));
    CHECK(FT_Select_Charmap(face, FT_ENCODING_UNICODE) == 0);
    glyph = FT_Get_Char_Index(face, 'A'); CHECK(glyph && FT_Get_Char_Index(face, 0x10ffff) == 0);
    CHECK(FT_Set_Pixel_Sizes(face, 0, 24) == 0 && FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT) == 0);
    CHECK(face->glyph->advance.x > 0 && face->glyph->metrics.height > 0);
    printf("[freetype-gate-A] engine=%d.%d.%d TrueType glyphs=%ld UPEM=%u Unicode metrics PASS\n",
           major, minor, patch, face->num_glyphs, face->units_per_EM);
    if (last >= 'B') {
        CHECK(FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL) == 0);
        CHECK(face->glyph->bitmap.pixel_mode == FT_PIXEL_MODE_GRAY && face->glyph->bitmap.pitch > 0);
        for (i = 0; i < face->glyph->bitmap.rows * (unsigned)face->glyph->bitmap.pitch; i++) {
            unsigned value = face->glyph->bitmap.buffer[i];
            if (value && value < 255) gray++;
            if (value == 255) solid++;
        }
        CHECK(gray > 0 && solid > 0);
        CHECK(FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT) == 0);
        FT_GlyphSlot_Embolden(face->glyph);
        CHECK(FT_Render_Glyph(face->glyph, FT_RENDER_MODE_MONO) == 0 &&
              face->glyph->bitmap.pixel_mode == FT_PIXEL_MODE_MONO);
        CHECK(FT_Get_Kerning(face, glyph, FT_Get_Char_Index(face, 'V'), FT_KERNING_UNFITTED, &kern) == 0 && kern.x < 0);
        {
            FT_Matrix transform = { 65536, 16384, 0, 65536 };
            FT_Set_Transform(face, &transform, NULL);
            CHECK(FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT) == 0 &&
                  FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL) == 0);
            FT_Set_Transform(face, NULL, NULL);
        }
        for (i = 0; i < 10000; i++) {
            CHECK(FT_Set_Pixel_Sizes(face, 0, 11 + i % 22) == 0);
            CHECK(FT_Load_Char(face, 33 + i % 94, FT_LOAD_RENDER) == 0);
        }
        printf("[freetype-gate-B] gray=%u solid=%u mono embolden kerning transform raster-rounds=10000 PASS\n", gray, solid);
    }
    CHECK(FT_Done_Face(face) == 0);
    if (last >= 'C') {
        unsigned char *guard = mmap(NULL, 8192, PROT_READ | PROT_WRITE,
                                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        CHECK(guard != MAP_FAILED && mprotect(guard + 4096, 4096, PROT_NONE) == 0);
        baseline_bytes = memory_stats.bytes; baseline_blocks = memory_stats.blocks;
        for (i = 1; i <= 256; i++) {
            unsigned char *short_font = guard + 4096 - i;
            memcpy(short_font, data, i);
            face = NULL;
            CHECK(FT_New_Memory_Face(library, short_font, i, 0, &face) != 0 && face == NULL);
            CHECK(memory_stats.bytes == baseline_bytes && memory_stats.blocks == baseline_blocks);
        }
        for (i = 0; i < 1024; i++) {
            unsigned char bad[128]; unsigned j;
            for (j = 0; j < sizeof(bad); j++) bad[j] = (unsigned char)(i * 31U + j * 17U);
            /* All signatures are invalid; no security claim about arbitrary valid-font mutations. */
            bad[0] = 0xff; bad[1] = 0xff; bad[2] = 0xff; bad[3] = 0xff;
            face = NULL;
            CHECK(FT_New_Memory_Face(library, bad, sizeof(bad), 0, &face) != 0 && face == NULL);
            CHECK(memory_stats.bytes == baseline_bytes && memory_stats.blocks == baseline_blocks);
        }
        for (i = 0; i < 32; i++) {
            unsigned retry;
            memory_stats.attempts = 0; memory_stats.faults = 0; memory_stats.fail_after = i; face = NULL;
            /* Later thresholds may exceed one face's allocations; keep going until an actual fault occurs. */
            for (retry = 0; retry < 64 && !memory_stats.faults; retry++) {
                FT_Error error = FT_New_Memory_Face(library, data, (FT_Long)size, 0, &face);
                if (!error) CHECK(face && FT_Done_Face(face) == 0);
                else CHECK(face == NULL);
                face = NULL;
            }
            memory_stats.fail_after = -1;
            CHECK(memory_stats.faults > 0);
            CHECK(memory_stats.bytes == baseline_bytes && memory_stats.blocks == baseline_blocks);
        }
        CHECK(munmap(guard, 8192) == 0);
        puts("[freetype-gate-C] truncations=256 guard-page invalid-signatures=1024 allocation-fault-cases=32 zero-leak PASS");
    }
    free(data);
    CHECK(engine_stop() == 0);
    return 0;
}
static int scanout_gate(void)
{
    area_id id, reference_id; void *address = NULL, *reference_address = NULL; uint32_t expected, actual;
    struct caribe_gfx_mode mode; struct caribe_gfx_blit blit;
    struct caribe_gfx_stats before, after;
    struct caribe_area_request stats;
    int fd, control, status; pid_t child; char arg[32];
    uint32_t *reference;
    reference_id = create_area("freetype-reference", &reference_address, WIDTH * HEIGHT * 4,
                               AREA_READ | AREA_WRITE, AREA_FULL_LOCK);
    CHECK(reference_id > 0 && reference_address);
    reference = reference_address;
    CHECK(render_frame(reference) == 0); expected = pixel_hash(reference);
    id = create_area("freetype-scanout", &address, WIDTH * HEIGHT * 4,
                     AREA_READ | AREA_WRITE, AREA_FULL_LOCK);
    CHECK(id > 0 && address);
    snprintf(arg, sizeof(arg), "%d", id);
    child = fork(); CHECK(child >= 0);
    if (!child) {
        execl("/bin/freetype-probe", "freetype-probe", "render-peer", arg, (char *)0);
        _exit(91);
    }
    CHECK(waitpid(child, &status, 0) == child && WIFEXITED(status) && !WEXITSTATUS(status));
    __sync_synchronize(); actual = pixel_hash(address);
    CHECK(actual == expected && memcmp(address, reference, WIDTH * HEIGHT * 4) == 0);
    fd = open("/dev/caribe-graphics", O_RDWR | O_CLOEXEC); CHECK(fd >= 0);
    CHECK(ioctl(fd, CARIBE_GFX_GET_MODE, &mode) == 0 && mode.width == WIDTH && mode.height == HEIGHT);
    CHECK(ioctl(fd, CARIBE_GFX_GET_STATS, &before) == 0);
    memset(&blit, 0, sizeof(blit)); blit.abi = CARIBE_GFX_ABI;
    blit.width = WIDTH; blit.height = HEIGHT; blit.stride = WIDTH * 4;
    blit.pixels = (uint32_t)(uintptr_t)address;
    CHECK(ioctl(fd, CARIBE_GFX_BLIT, &blit) == 0 && ioctl(fd, CARIBE_GFX_PRESENT, 0) == 0);
    CHECK(ioctl(fd, CARIBE_GFX_GET_STATS, &after) == 0 && after.blits == before.blits + 1 &&
          after.presents == before.presents + 1);
    CHECK(close(fd) == 0 && delete_area(id) == 0 && delete_area(reference_id) == 0);
    control = open("/dev/caribe-ipc", O_RDWR); CHECK(control >= 0);
    memset(&stats, 0, sizeof(stats)); stats.abi = CARIBE_AREA_ABI; stats.operation = CARIBE_AREA_STATS;
    CHECK(ioctl(control, CARIBE_AREA_CALL, &stats) == 0 && !stats.objects && !stats.views && !stats.pages);
    CHECK(close(control) == 0);
    printf("[freetype-gate-D] independent-exec shared-Sv32 bytes=1920000 frame-fnv32=%08x GPU-present zero-area-leak PASS\n", actual);
    return 0;
}
int main(int argc, char **argv)
{
    char last = 'D';
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc == 3 && !strcmp(argv[1], "render-peer")) {
        void *address = NULL;
        area_id id = clone_area("freetype-peer", &address, AREA_READ | AREA_WRITE,
                               AREA_FULL_LOCK, (area_id)atoi(argv[2]));
        CHECK(id > 0 && render_frame(address) == 0);
        __sync_synchronize(); CHECK(delete_area(id) == 0);
        return 0;
    }
    if (argc == 3 && !strcmp(argv[1], "--gate") && strlen(argv[2]) == 1) last = argv[2][0];
    else CHECK(argc == 1);
    CHECK(last >= 'A' && last <= 'D' && dependency_gates(last) == 0);
    if (last == 'D') CHECK(scanout_gate() == 0);
    printf("[freetype] gates A-%c PASS; authentic font engine, not Syllable AppServer; no Wayland/X11\n", last);
    return 0;
}
