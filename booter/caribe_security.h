/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef CARIBE_SECURITY_H
#define CARIBE_SECURITY_H
#include <stdint.h>
#include "security/catkey.h"

#define CARIBE_SECURITY_EVIDENCE_MAGIC 0x31534543u
typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t state;
    uint32_t flags;
    uint32_t cssbi_version;
    uint32_t cssbi_caps;
    uint32_t verified_images;
    uint32_t required_policy;
    uint8_t kernel_sha256[32];
    uint8_t initrd_sha256[32];
    uint8_t key_id[32];
} caribe_security_evidence;

void caribe_security_init(void);
void caribe_security_policy(const char *command_line);
void caribe_security_image(const char *subject, uint32_t permission,
                           const void *payload, uint32_t size,
                           const uint8_t *manifest, uint32_t manifest_size);
const caribe_security_evidence *caribe_security_get_evidence(void);
#endif
