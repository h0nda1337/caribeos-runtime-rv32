/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "security/catkey.h"
#include "monocypher-ed25519.h"
#include "mbedtls/sha256.h"

static uint32_t le32(const uint8_t *p)
{
    return p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static int equal(const uint8_t *a, const uint8_t *b, size_t n)
{
    uint8_t difference = 0;
    while (n--)
        difference |= *a++ ^ *b++;
    return difference == 0;
}

int catkey_sha256(const void *data, size_t size, uint8_t digest[32])
{
    if (!digest || (!data && size))
        return -1;
    return mbedtls_sha256(data, size, digest, 0);
}

int catkey_verify(const uint8_t *r, size_t size,
                  const uint8_t trusted_key[32], uint32_t trusted_role,
                  uint32_t allowed, uint32_t required, uint32_t kind,
                  const uint8_t subject[32], const uint8_t nonce[32],
                  const void *payload, uint32_t payload_size)
{
    static const uint8_t magic[8] = {'C','A','T','K','E','Y','1',0};
    static const uint8_t no_enrollment[32] = {0};
    uint8_t digest[32];
    uint32_t permissions;
    if (!r || !trusted_key || !subject || !nonce || (!payload && payload_size) ||
        size != CATKEY_RECORD_SIZE || !equal(r, magic, 8) ||
        le32(r + 8) != 1 || le32(r + 12) != kind ||
        (kind != CATKEY_KIND_IMAGE && kind != CATKEY_KIND_TOKEN))
        return CATKEY_FORMAT;
    /* The default zero-filled anchor represents no enrollment, never a key. */
    if (equal(trusted_key, no_enrollment, sizeof(no_enrollment)))
        return CATKEY_POLICY;
    if (!equal(r + 96, trusted_key, 32))
        return CATKEY_SIGNATURE;
    if (crypto_ed25519_check(r + CATKEY_BODY_SIZE, trusted_key,
                            r, CATKEY_BODY_SIZE) != 0)
        return CATKEY_SIGNATURE;
    permissions = le32(r + 20);
    if (le32(r + 16) != trusted_role || !required || !permissions ||
        (permissions & ~allowed) || (permissions & required) != required)
        return CATKEY_POLICY;
    /* Nonzero rollback generations require a persistent trusted counter. */
    if (le32(r + 24) != 0)
        return CATKEY_POLICY;
    if (!equal(r + 32, subject, 32) || !equal(r + 128, nonce, 32))
        return CATKEY_CONTEXT;
    if (le32(r + 28) != payload_size ||
        (kind == CATKEY_KIND_TOKEN && payload_size != 0))
        return CATKEY_DIGEST;
    if (catkey_sha256(payload, payload_size, digest) != 0 ||
        !equal(r + 64, digest, 32))
        return CATKEY_DIGEST;
    return CATKEY_OK;
}
