/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original software surface primitives; the Syllable adapter is separately
 * LGPL.
 */
#include "font8x8_basic.h"
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

uint32_t caribe_pixels[800 * 600];
void operator delete(void *ptr) noexcept __attribute__((weak));
void operator delete(void *ptr, size_t) noexcept __attribute__((weak));
void operator delete(void *ptr) noexcept { free(ptr); }
void operator delete(void *ptr, size_t) noexcept { free(ptr); }
extern "C" __attribute__((weak)) void __cxa_pure_virtual(void) { _exit(125); }

void caribe_fill(int x, int y, int w, int h, uint32_t pixel) {
  int right = x + w, bottom = y + h;
  if (x < 0)
    x = 0;
  if (y < 0)
    y = 0;
  if (right > 800)
    right = 800;
  if (bottom > 600)
    bottom = 600;
  for (int j = y; j < bottom; j++)
    for (int i = x; i < right; i++)
      caribe_pixels[j * 800 + i] = pixel;
}
void caribe_text(int x, int y, const char *text, uint32_t pixel, int scale) {
  for (; *text; text++, x += 8 * scale) {
    unsigned char c = (unsigned char)*text;
    if (c >= 128)
      c = '?';
    for (int row = 0; row < 8; row++)
      for (int col = 0; col < 8; col++)
        if (font8x8_basic[c][row] & (1 << col))
          caribe_fill(x + col * scale, y + row * scale, scale, scale, pixel);
  }
}
