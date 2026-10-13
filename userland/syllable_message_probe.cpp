/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Actual genuine Message data-core/transport tests; no Handler/Looper stubs.
 */
#include <util/message.h>
#include <gui/rect.h>
#include <gui/gfxtypes.h>
#include <atheos/msgport.h>
#include "message_io.h"
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <vector>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    std::printf("[syllable-message] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
static constexpr unsigned ROUNDS = 10000;

static std::vector<uint8> flatten(const os::Message &message)
{
    std::vector<uint8> bytes(message.GetFlattenedSize());
    if (message.Flatten(bytes.data(), bytes.size()) != 0) throw std::runtime_error("Flatten failed");
    return bytes;
}
static uint32 word(const uint8 *bytes, size_t offset)
{
    uint32 value;
    std::memcpy(&value, bytes + offset, 4);
    return value;
}
static void put(std::vector<uint8> &bytes, size_t offset, uint32 value)
{
    std::memcpy(bytes.data() + offset, &value, 4);
}
static bool child_ok(pid_t child)
{
    int status;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}
static int basics()
{
    os::Message message(73), nested(19);
    CHECK(nested.AddString("txt", "nested genuine Message") == 0);
    CHECK(message.AddInt8("a", -7) == 0 && message.AddInt16("odd", -3001) == 0);
    CHECK(message.AddInt32("value", -0x1234567) == 0 && message.AddInt32("value", 42) == 0);
    CHECK(message.AddInt64("wide", INT64_C(0x1122334455667788)) == 0);
    CHECK(message.AddBool("flag", true) == 0 && message.AddFloat("float", 1.25f) == 0);
    CHECK(message.AddDouble("dbl", -9.5) == 0 && message.AddString("txt", os::String("CaribeOS")) == 0);
    CHECK(message.AddMessage("nested", &nested) == 0);
    CHECK(message.AddPoint("point", os::Point(3.5f, 7.25f)) == 0);
    CHECK(message.AddIRect("rect", os::IRect(1, 2, 33, 44)) == 0);
    CHECK(message.AddColor32("color", os::Color32_s(17, 29, 41)) == 0);
    std::vector<uint8> bytes = flatten(message);
    for (size_t pos = 28; pos < bytes.size(); pos += word(bytes.data(), pos + 8)) {
        CHECK(word(bytes.data(), pos) == 0);
        CHECK(bytes[pos + 25] == 0 && bytes[pos + 26] == 0 && bytes[pos + 27] == 0);
    }
    os::Message decoded;
    CHECK(decoded.Unflatten(bytes.data(), bytes.size()) == 0 && decoded.GetCode() == 73);
    int8 v8; int16 v16; int32 v32; int64 v64; bool flag; float f; double d;
    CHECK(decoded.FindInt8("a", &v8) == 0 && v8 == -7);
    CHECK(decoded.FindInt16("odd", &v16) == 0 && v16 == -3001);
    CHECK(decoded.FindInt32("value", &v32, 1) == 0 && v32 == 42);
    CHECK(decoded.FindInt64("wide", &v64) == 0 && v64 == INT64_C(0x1122334455667788));
    CHECK(decoded.FindBool("flag", &flag) == 0 && flag);
    CHECK(decoded.FindFloat("float", &f) == 0 && f == 1.25f);
    CHECK(decoded.FindDouble("dbl", &d) == 0 && d == -9.5);
    os::String text; os::Message child; os::Point point; os::Rect rect; os::Color32_s color;
    CHECK(decoded.FindString("txt", &text) == 0 && text == "CaribeOS");
    CHECK(decoded.FindMessage("nested", &child) == 0 && child.GetCode() == 19);
    CHECK(decoded.FindPoint("point", &point) == 0 && point.x == 3.5f && point.y == 7.25f);
    CHECK(decoded.FindRect("rect", &rect) == 0 && rect.left == 1 && rect.bottom == 44);
    CHECK(decoded.FindColor32("color", &color) == 0 && color.red == 17 && color.blue == 41);
    CHECK(decoded.FindInt32("value", &v32, -1) == -1 && decoded.RemoveData("value", -1) == -1);
    os::Message copy(message); copy = copy; copy = decoded;
    CHECK(copy.RemoveData("value", 0) == 0 && copy.FindInt32("value", &v32) == 0 && v32 == 42);
    CHECK(copy.RemoveData("value", 0) == 0);
    bytes = flatten(copy); CHECK(decoded.Unflatten(bytes.data(), bytes.size()) == 0);
    CHECK(copy.RemoveName("txt") == 0 && copy.FindString("txt", &text) == -1);
    for (unsigned i = 0; i < 1000; ++i) { copy = message; copy = decoded; }
    copy.MakeEmpty(); CHECK(copy.IsEmpty() && copy.GetFlattenedSize() == 28);
    std::puts("[syllable-message-gate-A] genuine typed arrays nested String geometry copy remove alignment address-scrub PASS");
    return 0;
}
static int malformed()
{
    os::Message source(7), preserved(99);
    CHECK(source.AddString("odd", "bounded native message") == 0);
    CHECK(preserved.AddInt32("keep", 1234) == 0);
    auto bytes = flatten(source);
    uint8 *pages = static_cast<uint8 *>(mmap(nullptr, 12288, PROT_READ | PROT_WRITE,
                                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    CHECK(pages != MAP_FAILED && mprotect(pages + 8192, 4096, PROT_NONE) == 0);
    for (size_t length = 0; length < bytes.size(); ++length) {
        uint8 *end_aligned = pages + 8192 - length;
        std::memcpy(end_aligned, bytes.data(), length);
        CHECK(preserved.Unflatten(end_aligned, length) == -1 && errno == EINVAL);
        int32 value;
        CHECK(preserved.GetCode() == 99 && preserved.FindInt32("keep", &value) == 0 && value == 1234);
    }
    std::memcpy(pages + 8192 - bytes.size(), bytes.data(), bytes.size());
    CHECK(source.Unflatten(pages + 8192 - bytes.size(), bytes.size()) == 0);
    for (unsigned i = 0; i < ROUNDS; ++i) {
        auto invalid = bytes;
        switch (i % 8) {
        case 0: put(invalid, 0, 0xffffffff); break;
        case 1: put(invalid, 28 + 8, 0); break;
        case 2: put(invalid, 28 + 8, 0x7fffffff); break;
        case 3: put(invalid, 28 + 16, 0); break;
        case 4: put(invalid, 28 + 16, 0x7fffffff); break;
        case 5: put(invalid, 28 + 12, 0xffffffff); break;
        case 6: invalid[28 + 24] = 255; break;
        case 7: invalid.back() = 1; break;
        }
        uint8 *end_aligned = pages + 8192 - invalid.size();
        std::memcpy(end_aligned, invalid.data(), invalid.size());
        CHECK(preserved.Unflatten(end_aligned, invalid.size()) == -1 && errno == EINVAL);
        CHECK(preserved.GetCode() == 99);
    }
    uint8 tiny[27]; std::memset(tiny, 0x6d, sizeof(tiny));
    CHECK(source.Flatten(tiny, sizeof(tiny)) == -1 && errno == EOVERFLOW);
    for (uint8 value : tiny) CHECK(value == 0x6d);
    CHECK(source.Unflatten(nullptr, 28) == -1 && errno == EINVAL);
    CHECK(source.Unflatten(bytes.data(), 8193) == -1 && errno == EINVAL);
    std::string huge(9000, 'x'); auto before = flatten(source);
    CHECK(source.AddString("huge", huge.c_str()) == -1 && errno == EMSGSIZE && flatten(source) == before);
    os::Message nested(1);
    for (unsigned i = 0; i < 17; ++i) { os::Message next(2); CHECK(next.AddMessage("n", &nested) == 0); nested = next; }
    auto deep = flatten(nested); CHECK(source.Unflatten(deep.data(), deep.size()) == -1 && errno == EINVAL);
    CHECK(munmap(pages, 12288) == 0);
    std::puts("[syllable-message-gate-B] malformed=10000 all-truncations guard-page state-preservation overflow depth-limit PASS");
    return 0;
}
static os::Message packet(unsigned sequence)
{
    os::Message message(sequence);
    os::String text; text.Format("genuine Syllable Message %08u", sequence);
    if (sequence % 1000 == 0) text += std::string(5000, 's');
    if (message.AddInt32("sequence", sequence) || message.AddString("txt", text) ||
            message.AddInt64("wide", INT64_C(0x1122334455667788))) throw std::runtime_error("packet construction");
    return message;
}
static bool matches(const os::Message &message, unsigned sequence)
{
    int32 got; int64 wide; os::String text, expected;
    auto original = packet(sequence); original.FindString("txt", &expected);
    return message.GetCode() == static_cast<int>(sequence) && message.WasDelivered() &&
        message.FindInt32("sequence", &got) == 0 && got == static_cast<int32>(sequence) &&
        message.FindInt64("wide", &wide) == 0 && wide == INT64_C(0x1122334455667788) &&
        message.FindString("txt", &text) == 0 && text == expected;
}
static int peer(port_id destination, port_id handshake)
{
    port_id own = create_port("syllable-message-peer", 1); CHECK(own > 0);
    CHECK(send_msg_x(handshake, 0, &own, sizeof(own), 5000000) == 0);
    os::Message message(77);
    CHECK(message.ReadPort(own, 5000000) == -1 && errno == EINVAL && message.GetCode() == 77);
    int bad = 1; CHECK(send_msg_x(destination, 0xbad, &bad, sizeof(bad), 5000000) == 0);
    for (unsigned sequence = 0; sequence < ROUNDS; ++sequence) {
        CHECK(message.ReadPort(own, 5000000) == 0 && matches(message, sequence));
        CHECK(message.PostPort(destination) == 0);
    }
    CHECK(delete_port(own) == 0);
    return 0;
}
static int transport()
{
    port_id receive = create_port("syllable-message-server", 1), handshake = create_port("syllable-message-hello", 1);
    CHECK(receive > 0 && handshake > 0);
    char server[32], hello[32]; std::snprintf(server, sizeof(server), "%d", receive); std::snprintf(hello, sizeof(hello), "%d", handshake);
    pid_t child = fork(); CHECK(child >= 0);
    if (child == 0) { execl("/bin/syllable-message-probe", "syllable-message-probe", "--peer", server, hello, nullptr); _exit(12); }
    uint32 code = 0; port_id destination = -1; size_t received = 0;
    CHECK(caribe_get_message(handshake, &code, &destination, sizeof(destination), 5000000, &received) == 0);
    CHECK(received == sizeof(destination) && destination > 0 && delete_port(handshake) == 0);
    uint8 short_frame[3] = {0, 0, 0};
    CHECK(send_msg_x(destination, 0, short_frame, sizeof(short_frame), 5000000) == 0);
    int bad = 0; CHECK(caribe_get_message(receive, &code, &bad, sizeof(bad), 5000000, &received) == 0);
    CHECK(received == sizeof(bad) && code == 0xbad && bad == 1);
    os::Message reply;
    for (unsigned sequence = 0; sequence < ROUNDS; ++sequence) {
        auto message = packet(sequence);
        CHECK(message.PostPort(destination) == 0 && reply.ReadPort(receive, 5000000) == 0);
        CHECK(matches(reply, sequence));
    }
    CHECK(child_ok(child) && delete_port(receive) == 0);
    std::puts("[syllable-message-gate-C] independent exec real Post/Read rounds=10000 short-frame rejection exact-byte-count PASS");
    return 0;
}
static int lifecycle()
{
    os::Message parent(123); CHECK(parent.AddString("txt", "parent live Message") == 0);
    for (unsigned i = 0; i < 16; ++i) {
        pid_t child = fork(); CHECK(child >= 0);
        if (child == 0) { parent.MakeEmpty(); execl("/bin/syllable-message-probe", "syllable-message-probe", "--lifecycle", nullptr); _exit(13); }
        os::String text;
        CHECK(child_ok(child) && parent.FindString("txt", &text) == 0 && text == "parent live Message");
    }
    std::puts("[syllable-message-gate-D] Message heap fork-exec=16 parent isolation PASS");
    return 0;
}
int main(int argc, char **argv)
{
    try {
        if (argc == 2 && std::strcmp(argv[1], "--lifecycle") == 0) { os::Message fresh(321); return fresh.IsEmpty() && fresh.GetCode() == 321 ? 0 : 14; }
        if (argc == 4 && std::strcmp(argv[1], "--peer") == 0)
            return peer(std::strtol(argv[2], nullptr, 10), std::strtol(argv[3], nullptr, 10));
        CHECK(basics() == 0 && malformed() == 0 && transport() == 0 && lifecycle() == 0);
        std::puts("[syllable-message] genuine Message data-core gates A-D PASS; no Looper stubs, no Wayland/X11");
        return 0;
    } catch (const std::exception &error) {
        std::printf("[syllable-message] FAIL uncaught exception: %s\n", error.what());
        return 1;
    }
}
