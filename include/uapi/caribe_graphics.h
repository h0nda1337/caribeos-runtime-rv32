/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef CARIBE_GRAPHICS_ABI_H
#define CARIBE_GRAPHICS_ABI_H
#include <stdint.h>
#define CARIBE_GFX_ABI 0x00010000U
#define CARIBE_GFX_GET_MODE 0x80184301U
#define CARIBE_GFX_BLIT 0x40204302U
#define CARIBE_GFX_PRESENT 0x00004303U
#define CARIBE_GFX_GET_EVENT 0x80104304U
#define CARIBE_GFX_GET_STATS 0x80104305U
#define CARIBE_GFX_FORMAT_XRGB8888 1U
struct caribe_gfx_mode {
  uint32_t abi, width, height, stride, format, capabilities;
};
struct caribe_gfx_blit {
  uint32_t abi, x, y, width, height, stride, pixels, reserved;
};
struct caribe_gfx_event {
  uint32_t device;
  uint16_t type, code;
  int32_t value;
  uint32_t sequence;
};
struct caribe_gfx_stats {
  uint32_t presents, blits, events, dropped;
};
typedef char
    caribe_gfx_mode_abi_size[(sizeof(struct caribe_gfx_mode) == 24) ? 1 : -1];
typedef char
    caribe_gfx_blit_abi_size[(sizeof(struct caribe_gfx_blit) == 32) ? 1 : -1];
typedef char
    caribe_gfx_event_abi_size[(sizeof(struct caribe_gfx_event) == 16) ? 1 : -1];
typedef char
    caribe_gfx_stats_abi_size[(sizeof(struct caribe_gfx_stats) == 16) ? 1 : -1];
#endif
