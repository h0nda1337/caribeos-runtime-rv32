/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef CARIBE_SSBI_H
#define CARIBE_SSBI_H

/* Experimental SBI namespace; no assigned vendor identity is claimed. */
#define CSSBI_EID                   0x08435342UL
#define CSSBI_ABI_VERSION           0x00010000UL
#define CSSBI_GET_VERSION           0UL
#define CSSBI_GET_CAPABILITIES      1UL
#define CSSBI_GET_SECURITY_STATE    2UL
#define CSSBI_VERIFY_IMAGE          3UL
#define CSSBI_KEY_GENERATE          4UL
#define CSSBI_KEY_GET_PUBLIC        5UL
#define CSSBI_SIGN_DATA             6UL
#define CSSBI_VERIFY_SIGNATURE      7UL
#define CSSBI_VERIFY_TOKEN          8UL
#define CSSBI_GET_MEASUREMENTS      9UL
#define CSSBI_SIGN_ATTESTATION     10UL
#define CSSBI_ROLLBACK_CHECK       11UL
#define CSSBI_DISCOVERY_CAPS        0x00000007UL

#define CSSBI_STATE_GREEN           0UL
#define CSSBI_STATE_YELLOW          1UL
#define CSSBI_STATE_ORANGE          2UL
#define CSSBI_STATE_RED             3UL
#define CSSBI_STATE_MASK          0xffUL
#define CSSBI_FLAG_SIMULATED     0x100UL
#define CSSBI_FLAG_ROOT_UNVERIFIED 0x200UL

#define CSSBI_SUCCESS               0
#define CSSBI_ERR_NOT_SUPPORTED    -2
#define CSSBI_ERR_INVALID_PARAM    -3
#define CSSBI_ERR_DENIED           -4
#define CSSBI_ERR_INVALID_ADDRESS  -5
#endif
