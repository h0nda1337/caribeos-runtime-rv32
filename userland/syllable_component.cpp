/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Test application linked to the LGPL-2.0-only Syllable WindowDecorator.
 */
#include "adapter.h"
#include "defaultdecorator.h"
#include "uapi/caribe_graphics.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>
struct Window {
  int x, y, w, h;
  Layer layer;
  DefaultDecorator decorator;
  const char *title;
  Window(int a, int b, int c, int d, const char *name)
      : x(a), y(b), w(c), h(d), layer(c, d), decorator(&layer, 0), title(name) {
    decorator.FrameSized(os::Rect(0, 0, w - 1, h - 1));
    decorator.SetTitle(title);
  }
  bool Contains(int px, int py) {
    return px >= x && py >= y && px < x + w && py < y + h;
  }
  void Draw(bool focus, int keys) {
    layer.Position(x, y);
    caribe_fill(x, y, w, h, 0xe6e9ed);
    decorator.SetFocusState(focus);
    decorator.Render(layer.GetBounds());
    caribe_text(x + 20, y + 52, title, 0x24282e, 1);
    if (w > 400) {
      caribe_text(x + 20, y + 90, "AppServer / DefaultDecorator", 0x24282e, 1);
      caribe_text(x + 20, y + 118, "Kurt Skauen / Syllable Team", 0x24282e, 1);
      caribe_text(x + 20, y + 146, "RV32IMACSU / native XNU graphics", 0x24282e,
                  1);
      static const uint32_t colors[] = {0xde534a, 0xe8b949, 0x46a87a,
                                        0x458bc4, 0xc86699, 0x272c33};
      for (int i = 0; i < 6; i++)
        caribe_fill(x + 20 + i * 62, y + 180, 50, 38, colors[i]);
      char value[80];
      snprintf(value, sizeof(value), "Keyboard events: %d", keys);
      caribe_text(x + 20, y + 240, value, 0x24282e, 1);
    } else {
      caribe_text(x + 18, y + 86, "XNU-owned scanout", 0x24282e, 1);
      caribe_text(x + 18, y + 114, "S-mode / Sv32 / CPU0", 0x24282e, 1);
    }
  }
};
static int gfx_fd;
static int fail(const char *operation) {
  printf("[graphics] FAIL %s errno=%d\n", operation, errno);
  return 1;
}
static int present() {
  struct caribe_gfx_blit b = {CARIBE_GFX_ABI,
                              0,
                              0,
                              800,
                              600,
                              3200,
                              (uint32_t)(uintptr_t)caribe_pixels,
                              0};
  if (ioctl(gfx_fd, CARIBE_GFX_BLIT, &b) < 0 ||
      ioctl(gfx_fd, CARIBE_GFX_PRESENT, 0) < 0)
    return -1;
  return 0;
}
static int validate_abi() {
  struct caribe_gfx_mode mode;
  int proc_fd = open("/proc/self/fdinfo/1", O_RDONLY);
  if (proc_fd < 0)
    return -1;
  int result = ioctl(proc_fd, CARIBE_GFX_GET_MODE, &mode);
  int saved_errno = errno;
  close(proc_fd);
  if (result != -1 || saved_errno != ENOTTY)
    return -1;
  struct caribe_gfx_blit b = {CARIBE_GFX_ABI, 800, 0, 1, 1, 4, 0, 0};
  if (ioctl(gfx_fd, CARIBE_GFX_BLIT, &b) != -1 || errno != EINVAL)
    return -1;
  b.x = 0;
  b.pixels = 0x80000000U;
  if (ioctl(gfx_fd, CARIBE_GFX_BLIT, &b) != -1 || errno != EFAULT)
    return -1;
  if (ioctl(gfx_fd, CARIBE_GFX_GET_MODE, (void *)0x80000000U) != -1 ||
      errno != EFAULT)
    return -1;
  if (ioctl(gfx_fd, 0xDEAD, 0) != -1 || errno != ENOTTY)
    return -1;
  b.width = 0xffffffffU;
  if (ioctl(gfx_fd, CARIBE_GFX_BLIT, &b) != -1 || errno != EINVAL)
    return -1;
  b.width = 1;
  b.height = 600;
  b.stride = 0xffffffffU;
  if (ioctl(gfx_fd, CARIBE_GFX_BLIT, &b) != -1 || errno != EINVAL)
    return -1;
  puts("[graphics-gate-B] bounds overflow kernel-pointer fd-kind isolation and "
       "ioctl rejection PASS");
  return 0;
}
int main() {
  setvbuf(stdout, NULL, _IONBF, 0);
  gfx_fd = open("/dev/caribe-graphics", O_RDWR | O_CLOEXEC);
  if (gfx_fd < 0)
    return fail("open native graphics");
  struct caribe_gfx_mode mode;
  if (ioctl(gfx_fd, CARIBE_GFX_GET_MODE, &mode) < 0 ||
      mode.abi != CARIBE_GFX_ABI || mode.width != 800 || mode.height != 600 ||
      mode.stride != 3200 || mode.format != CARIBE_GFX_FORMAT_XRGB8888)
    return fail("mode/ABI");
  if (validate_abi() < 0)
    return fail("ABI negative gates");
  struct caribe_gfx_event stale;
  while (ioctl(gfx_fd, CARIBE_GFX_GET_EVENT, &stale) == 0) {
  }
  if (errno != EAGAIN)
    return fail("initial input queue");
  struct caribe_gfx_stats baseline;
  if (ioctl(gfx_fd, CARIBE_GFX_GET_STATS, &baseline) < 0)
    return fail("initial counters");
  Window first(72, 102, 480, 290, "Syllable Decorator");
  Window second(470, 330, 290, 166, "CaribeOS");
  int active = 0, mx = 650, my = 230, keys = 0, drag = -1, dx = 0, dy = 0;
  bool running = true, dirty = true;
  int down = 0;
  uint32_t sequence = baseline.events;
  puts("[graphics-gate-C] independent RV32-musl Syllable DefaultDecorator "
       "process started PASS");
  while (running) {
    struct caribe_gfx_event event;
    while (ioctl(gfx_fd, CARIBE_GFX_GET_EVENT, &event) == 0) {
      if (event.sequence != ++sequence)
        return fail("input sequence loss/duplication");
      if (event.type == 3) {
        if (event.code == 0)
          mx = int(int64_t(event.value) * 799 / 32767);
        if (event.code == 1)
          my = int(int64_t(event.value) * 599 / 32767);
        dirty = true;
      }
      if (event.type == 2) {
        if (event.code == 0)
          mx += event.value;
        if (event.code == 1)
          my += event.value;
        dirty = true;
      }
      if (mx < 0)
        mx = 0;
      if (my < 0)
        my = 0;
      if (mx > 799)
        mx = 799;
      if (my > 599)
        my = 599;
      if (event.type == 1 && event.code == 272) {
        down = event.value;
        if (down) {
          if (second.Contains(mx, my))
            active = 1;
          else if (first.Contains(mx, my))
            active = 0;
          Window &w = active ? second : first;
          os::WindowDecorator::hit_item hit =
              w.decorator.HitTest(os::Point(mx - w.x, my - w.y));
          if (hit == os::WindowDecorator::HIT_DRAG) {
            drag = active;
            dx = mx - w.x;
            dy = my - w.y;
          }
          printf("[graphics-gate-D] mouse button focus=%d hit=%d PASS\n",
                 active, int(hit));
        } else
          drag = -1;
        dirty = true;
      }
      if (down && drag >= 0 && (event.type == 2 || event.type == 3)) {
        Window &w = drag ? second : first;
        w.x = mx - dx;
        w.y = my - dy;
        if (w.x < 0)
          w.x = 0;
        if (w.y < 38)
          w.y = 38;
        if (w.x > 800 - w.w)
          w.x = 800 - w.w;
        if (w.y > 600 - w.h - 30)
          w.y = 600 - w.h - 30;
        dirty = true;
      }
      if (event.type == 1 && event.value == 1 && event.code < 256) {
        keys++;
        if (event.code == 15)
          active = 1 - active;
        if (event.code == 1)
          running = false;
        printf("[graphics-gate-D] keyboard code=%u count=%d PASS\n", event.code,
               keys);
        dirty = true;
      }
    }
    if (errno != EAGAIN)
      return fail("input queue");
    if (dirty) {
      caribe_fill(0, 0, 800, 600, 0x3c454b);
      caribe_fill(0, 0, 800, 38, 0x252a2e);
      caribe_text(18, 11, "CaribeOS", 0xffffff, 2);
      caribe_text(600, 15, "RV32 / XNU", 0xb6d6c1, 1);
      if (active) {
        first.Draw(false, keys);
        second.Draw(true, keys);
      } else {
        second.Draw(false, keys);
        first.Draw(true, keys);
      }
      caribe_fill(0, 570, 800, 30, 0x252a2e);
      caribe_text(18, 581, "Syllable AppServer component", 0xe5e8eb, 1);
      caribe_text(610, 581, "Graphics v0.1", 0xb6d6c1, 1);
      for (int y = 0; y < 16; y++)
        for (int x = 0; x <= y / 2; x++)
          caribe_fill(mx + x, my + y, 1, 1,
                      x == 0 || x == y / 2 ? 0x101010 : 0xffffff);
      if (present() < 0)
        return fail("present");
      dirty = false;
      puts("[graphics-gate-C] userspace frame presented PASS");
    }
    struct timespec delay = {0, 10000000};
    nanosleep(&delay, NULL);
  }
  struct caribe_gfx_stats stats;
  if (ioctl(gfx_fd, CARIBE_GFX_GET_STATS, &stats) < 0 ||
      stats.dropped != baseline.dropped || stats.events != sequence ||
      stats.blits - baseline.blits != stats.presents - baseline.presents)
    return fail("event/frame accounting");
  printf("[graphics-gate-E] clean exit frames=%u blits=%u events=%u dropped=%u "
         "PASS\n",
         stats.presents - baseline.presents, stats.blits - baseline.blits,
         stats.events - baseline.events, stats.dropped - baseline.dropped);
  close(gfx_fd);
  return 0;
}
