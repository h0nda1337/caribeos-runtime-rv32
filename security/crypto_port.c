/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include <stddef.h>
#include <stdint.h>

void mbedtls_platform_zeroize(void *buffer, size_t length)
{
    volatile uint8_t *p = buffer;
    while (length--)
        *p++ = 0;
}

#ifdef CARIBE_FREESTANDING
void *memset(void *dst, int value, size_t length)
{
    uint8_t *p = dst;
    while (length--)
        *p++ = (uint8_t)value;
    return dst;
}

void *memcpy(void *dst, const void *src, size_t length)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (length--)
        *d++ = *s++;
    return dst;
}
#endif
