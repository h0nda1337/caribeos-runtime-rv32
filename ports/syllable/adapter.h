/*
 * CaribeOS adaptation of Syllable AppServer's Layer/WindowDecorator interface.
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: LGPL-2.0-only
 * See build/syllable-port/COPYING.LIB and ports/syllable/README.md.
 */
#ifndef CARIBE_SYLLABLE_ADAPTER_H
#define CARIBE_SYLLABLE_ADAPTER_H
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
typedef uint32_t uint32;
inline float caribe_max(float a, float b) { return a > b ? a : b; }
class CaribeTitle {
    char text[160];

  public:
    CaribeTitle() { text[0] = 0; }
    CaribeTitle &operator=(const char *value) {
        size_t n = strlen(value);
        if (n >= sizeof(text))
            n = sizeof(text) - 1;
        memcpy(text, value, n);
        text[n] = 0;
        return *this;
    }
    const char *c_str() const { return text; }
};
namespace os {
struct Point {
    float x, y;
    Point(float a = 0, float b = 0) : x(a), y(b) {}
};
struct Rect {
    float left, top, right, bottom;
    Rect(float l = 0, float t = 0, float r = -1, float b = -1)
        : left(l), top(t), right(r), bottom(b) {}
    float Width() const { return right - left; }
    float Height() const { return bottom - top; }
    Point Size() const { return Point(Width(), Height()); }
    Rect Bounds() const { return Rect(0, 0, Width(), Height()); }
    bool DoIntersect(const Point &p) const {
        return p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;
    }
    void MoveTo(float x, float y) {
        left += x;
        right += x;
        top += y;
        bottom += y;
    }
};
struct Color32_s {
    uint8_t red, green, blue, alpha;
    Color32_s(uint8_t r = 0, uint8_t g = 0, uint8_t b = 0, uint8_t a = 255)
        : red(r), green(g), blue(b), alpha(a) {}
    uint32 Pixel() const { return (uint32(red) << 16) | (uint32(green) << 8) | blue; }
};
struct font_height {
    float ascender, descender, line_gap;
};
enum {
    WND_NO_CLOSE_BUT = 1,
    WND_NO_ZOOM_BUT = 2,
    WND_NO_DEPTH_BUT = 4,
    WND_NOT_MOVEABLE = 8,
    WND_NO_TITLE = 64,
    WND_NO_BORDER = 128
};
enum { FRAME_RAISED = 1, FRAME_RECESSED = 2, FRAME_THIN = 4, FRAME_TRANSPARENT = 8 };
enum { COL_SEL_WND_BORDER = 3, COL_NORMAL_WND_BORDER = 4 };
inline Color32_s get_default_color(int which) {
    return which == COL_SEL_WND_BORDER ? Color32_s(0x66, 0x88, 0xbb) : Color32_s(0x78, 0x78, 0x78);
}
} // namespace os
extern uint32_t caribe_pixels[800 * 600];
void caribe_fill(int x, int y, int w, int h, uint32_t pixel);
void caribe_text(int x, int y, const char *text, uint32_t pixel, int scale = 1);
class Layer {
    int x, y, w, h, pen_x, pen_y;
    os::Color32_s foreground;

  public:
    Layer(int width, int height) : x(0), y(0), w(width), h(height), pen_x(0), pen_y(0) {}
    void Position(int a, int b) {
        x = a;
        y = b;
    }
    os::Rect GetBounds() const { return os::Rect(0, 0, w - 1, h - 1); }
    os::font_height GetFontHeight() const { return {16, 4, 0}; }
    void Invalidate() {}
    void Invalidate(const os::Rect &) {}
    void FillRect(const os::Rect &r, const os::Color32_s &c) {
        caribe_fill(x + int(r.left), y + int(r.top), int(r.Width()) + 1, int(r.Height()) + 1,
                    c.Pixel());
    }
    void DrawFrame(const os::Rect &r, uint32 flags) {
        uint32_t shine = (flags & os::FRAME_RECESSED) ? 0x303030 : 0xffffff;
        uint32_t shade = (flags & os::FRAME_RECESSED) ? 0xffffff : 0x303030;
        int l = x + int(r.left), t = y + int(r.top), width = int(r.Width()) + 1,
            height = int(r.Height()) + 1;
        caribe_fill(l, t, width, 1, shine);
        caribe_fill(l, t, 1, height, shine);
        caribe_fill(l, t + height - 1, width, 1, shade);
        caribe_fill(l + width - 1, t, 1, height, shade);
        if (!(flags & os::FRAME_THIN) && width > 2 && height > 2) {
            caribe_fill(l + 1, t + 1, width - 2, 1, shine);
            caribe_fill(l + 1, t + 1, 1, height - 2, shine);
            caribe_fill(l + 1, t + height - 2, width - 2, 1, shade);
            caribe_fill(l + width - 2, t + 1, 1, height - 2, shade);
        }
    }
    void SetFgColor(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
        foreground = os::Color32_s(r, g, b, a);
    }
    void SetBgColor(const os::Color32_s &) {}
    void MovePenTo(float a, float b) {
        pen_x = int(a);
        pen_y = int(b);
    }
    void DrawString(const char *text, int) {
        caribe_text(x + pen_x, y + pen_y - 16, text, foreground.Pixel(), 2);
    }
};
#endif
