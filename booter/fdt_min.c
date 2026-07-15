#include <stdint.h>
#include <stddef.h>
#include "booter/fdt_min.h"

#define FDT_MAGIC 0xd00dfeed
#define FDT_BEGIN_NODE 1
#define FDT_END_NODE   2
#define FDT_PROP       3
#define FDT_NOP        4
#define FDT_END        9

static inline uint32_t be32(const void *p){ return fdt_be32(p); }
static inline __attribute__((unused)) const char* strz(const char *p){ return p; }

static int streq(const char *a, const char *b){
    while(*a && *b && *a == *b){ a++; b++; }
    return *a == 0 && *b == 0;
}

static int compat_matches(const char *data, int len, const char *needle){
    /* 'compatible' es una lista de strings \0 separados */
    int i = 0;
    int nlen = 0; while(needle[nlen]) nlen++;
    while(i < len){
        const char *s = data + i;
        int sl = 0; while(i+sl < len && data[i+sl]) sl++;
        if(sl==nlen){
            int ok = 1;
            for(int j=0;j<sl;j++) if(s[j]!=needle[j]) { ok=0; break; }
            if(ok) return 1;
        }
        i += sl+1;
    }
    return 0;
}

int fdt_find_reg_base(const void *blob, const char *compat, uint32_t *out_base){
    const uint8_t *dtb = (const uint8_t*)blob;
    if(!dtb || !compat || !out_base) return -1;

    /* header: big-endian */
    uint32_t magic = be32(dtb+0x0);
    if(magic != FDT_MAGIC) return -2;

    uint32_t off_struct = be32(dtb+0x8);
    uint32_t off_strings= be32(dtb+0xc);

    const uint8_t *p = dtb + off_struct;
    const char *strs = (const char*)(dtb + off_strings);

    /* pequeña pila de "match" por profundidad */
    uint8_t match_stack[32]; int sp = -1;

    while(1){
        uint32_t token = be32(p); p += 4;
        switch(token){
            case FDT_BEGIN_NODE: {
                /* nombre del nodo (string \0); alinear a 4 */
                const char *name = (const char*)p;
                (void)name;
                while(*p) p++;
                p++;
                while(((uintptr_t)p) & 3) p++;
                if(sp < 31) match_stack[++sp] = 0; /* por defecto: no coincide */
                break;
            }
            case FDT_END_NODE: {
                if(sp >= 0) sp--;
                break;
            }
            case FDT_PROP: {
                uint32_t len  = be32(p); p += 4;
                uint32_t nameoff = be32(p); p += 4;
                const char *pname = strs + nameoff;
                const uint8_t *pdata = p;
                p += len;
                while(((uintptr_t)p) & 3) p++;

                if(sp < 0) break; /* por robustez */

                /* compatible */
                if(pname[0]=='c' && pname[1]=='o' && pname[2]=='m' && pname[3]=='p'){
                    if(compat_matches((const char*)pdata, (int)len, compat)){
                        match_stack[sp] = 1;
                    }
                }

                /* reg */
                if(pname[0]=='r' && pname[1]=='e' && pname[2]=='g' && pname[3]==0){
                    if(match_stack[sp]){
                        /* Toma la primera celda como base (32-bit): suficiente para QEMU virt */
                        if(len >= 4){
                            *out_base = be32(pdata);
                            return 0;
                        }
                    }
                }
                break;
            }
            case FDT_NOP:
                break;
            case FDT_END:
                return -3;
            default:
                /* token desconocido => aborta suavemente */
                return -4;
        }
    }
}

int fdt_get_chosen_bootargs(const void *blob, char *out, uint32_t out_cap){
    const uint8_t *dtb = (const uint8_t*)blob;
    if(!dtb || !out || out_cap == 0) return -1;
    out[0] = 0;

    if(be32(dtb+0x0) != FDT_MAGIC) return -2;

    uint32_t off_struct = be32(dtb+0x8);
    uint32_t off_strings= be32(dtb+0xc);
    const uint8_t *p = dtb + off_struct;
    const char *strs = (const char*)(dtb + off_strings);
    int depth = -1;
    int chosen_depth = -1;

    while(1){
        uint32_t token = be32(p); p += 4;
        switch(token){
            case FDT_BEGIN_NODE: {
                const char *name = (const char*)p;
                depth++;
                if(depth == 1 && streq(name, "chosen"))
                    chosen_depth = depth;
                while(*p) p++;
                p++;
                while(((uintptr_t)p) & 3) p++;
                break;
            }
            case FDT_END_NODE:
                if(depth == chosen_depth)
                    chosen_depth = -1;
                depth--;
                break;
            case FDT_PROP: {
                uint32_t len  = be32(p); p += 4;
                uint32_t nameoff = be32(p); p += 4;
                const char *pname = strs + nameoff;
                const uint8_t *pdata = p;
                p += len;
                while(((uintptr_t)p) & 3) p++;

                if(depth == chosen_depth && streq(pname, "bootargs")){
                    uint32_t n = 0;
                    while(n + 1 < out_cap && n < len && pdata[n]){
                        out[n] = (char)pdata[n];
                        n++;
                    }
                    out[n] = 0;
                    return n ? 0 : -3;
                }
                break;
            }
            case FDT_NOP:
                break;
            case FDT_END:
                return -4;
            default:
                return -5;
        }
    }
}

uint32_t fdt_count_cpus(const void *blob){
    const uint8_t *dtb = (const uint8_t*)blob;
    if(!dtb || be32(dtb+0x0) != FDT_MAGIC) return 0;

    uint32_t off_struct = be32(dtb+0x8);
    uint32_t off_strings= be32(dtb+0xc);
    const uint8_t *p = dtb + off_struct;
    const char *strs = (const char*)(dtb + off_strings);
    uint8_t cpu_stack[32];
    int sp = -1;
    uint32_t count = 0;

    while(1){
        uint32_t token = be32(p); p += 4;
        switch(token){
            case FDT_BEGIN_NODE:
                while(*p) p++;
                p++;
                while(((uintptr_t)p) & 3) p++;
                if(sp < 31) cpu_stack[++sp] = 0;
                break;
            case FDT_END_NODE:
                if(sp >= 0){
                    if(cpu_stack[sp])
                        count++;
                    sp--;
                }
                break;
            case FDT_PROP: {
                uint32_t len  = be32(p); p += 4;
                uint32_t nameoff = be32(p); p += 4;
                const char *pname = strs + nameoff;
                const uint8_t *pdata = p;
                p += len;
                while(((uintptr_t)p) & 3) p++;

                if(sp >= 0 && streq(pname, "device_type") &&
                   len >= 4 && pdata[0] == 'c' && pdata[1] == 'p' &&
                   pdata[2] == 'u' && pdata[3] == 0) {
                    cpu_stack[sp] = 1;
                }
                break;
            }
            case FDT_NOP:
                break;
            case FDT_END:
                return count;
            default:
                return count;
        }
    }
}
