/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef CARIBE_HYPERVISOR_H
#define CARIBE_HYPERVISOR_H
#include <stdint.h>
#include "include/uapi/caribe_ssbi.h"

/* Contract only: enabling HS/VS requires H and a separately verified backend. */
#define CARIBE_HV_ABI_VERSION 1u
#define CARIBE_HV_F_REQUIRE_H 1u
#define CARIBE_HV_F_GUEST_CSSBI_DENY 2u
typedef struct {
    uint32_t version, size, flags, guest_id;
    uint32_t ram_base, ram_size, vcpu_count, reserved;
    uint32_t entry, dtb, security_evidence, security_evidence_size;
} caribe_hv_guest_config;

/* Default guest mediation grants no host firmware services. */
static inline int caribe_hv_guest_cssbi_result(uint32_t operation)
{
    (void)operation;
    return CSSBI_ERR_DENIED;
}
#endif
