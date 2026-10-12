/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef CARIBE_CATKEY_H
#define CARIBE_CATKEY_H
#include <stdint.h>
#include <stddef.h>

#define CATKEY_RECORD_SIZE 224u
#define CATKEY_BODY_SIZE 160u
#define CATKEY_KIND_IMAGE 1u
#define CATKEY_KIND_TOKEN 2u
#define CATKEY_ROLE_FIRMWARE 1u
#define CATKEY_ROLE_DEVELOPMENT 2u
#define CATKEY_ROLE_MAINTENANCE 3u
#define CATKEY_ROLE_OWNER 4u
#define CATKEY_ROLE_ATTESTATION 5u
#define CATKEY_PERM_KERNEL 1u
#define CATKEY_PERM_INITRD 2u
#define CATKEY_PERM_MAINTENANCE 4u
#define CATKEY_PERM_FIRMWARE 8u
#define CATKEY_OK 0
#define CATKEY_FORMAT -1
#define CATKEY_SIGNATURE -2
#define CATKEY_POLICY -3
#define CATKEY_DIGEST -4
#define CATKEY_CONTEXT -5

int catkey_sha256(const void *data, size_t size, uint8_t digest[32]);
/* Authority comes from trusted_key and its locally enrolled role/permissions. */
int catkey_verify(const uint8_t *record, size_t size,
                  const uint8_t trusted_key[32], uint32_t trusted_role,
                  uint32_t allowed_permissions, uint32_t required_permission,
                  uint32_t kind, const uint8_t subject[32],
                  const uint8_t nonce[32], const void *payload,
                  uint32_t payload_size);
#endif
