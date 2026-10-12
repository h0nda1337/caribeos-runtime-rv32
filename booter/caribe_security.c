/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "booter/caribe_security.h"
#include "booter/sbi.h"
#include "include/uapi/caribe_ssbi.h"
#include "build/security-config.h"

static const uint8_t development_key[32] = CARIBE_DEV_PUBLIC_KEY;
static caribe_security_evidence evidence;
void uart_puts(const char *);
void uart_puthex32(uint32_t);

static void __attribute__((noreturn)) fail_closed(const char *reason)
{
    evidence.state = CSSBI_STATE_RED;
    uart_puts("\r\n[CaribeSecurity] RED: ");
    uart_puts(reason);
    uart_puts("; boot halted before ELF execution\r\n");
    __asm__ volatile("csrci sstatus, 2" ::: "memory");
    for (;;)
        __asm__ volatile("wfi");
}

void caribe_security_init(void)
{
    struct sbi_ret r;
    evidence.magic = CARIBE_SECURITY_EVIDENCE_MAGIC;
    evidence.version = 1;
    evidence.state = CSSBI_STATE_ORANGE;
    evidence.flags = CSSBI_FLAG_ROOT_UNVERIFIED;
    catkey_sha256(development_key, sizeof(development_key), evidence.key_id);
    r = sbi_call(0x10, 3, CSSBI_EID, 0, 0, 0);
    if (r.error == 0 && r.value != 0) {
        r = sbi_call(CSSBI_EID, CSSBI_GET_VERSION, 0, 0, 0, 0);
        if (r.error == 0 && (uint32_t)r.value == CSSBI_ABI_VERSION) {
            evidence.cssbi_version = (uint32_t)r.value;
            r = sbi_call(CSSBI_EID, CSSBI_GET_CAPABILITIES, 0, 0, 0, 0);
            if (r.error == 0)
                evidence.cssbi_caps = (uint32_t)r.value;
            r = sbi_call(CSSBI_EID, CSSBI_GET_SECURITY_STATE, 0, 0, 0, 0);
            /* A firmware claim cannot establish an authenticated root. */
            if (r.error == 0)
                evidence.flags |= (uint32_t)r.value & CSSBI_FLAG_SIMULATED;
            uart_puts("[CaribeSecurity] CaribeSSBI negotiated version=");
            uart_puthex32(evidence.cssbi_version);
            uart_puts(" capabilities=");
            uart_puthex32(evidence.cssbi_caps);
            uart_puts("\r\n");
            r = sbi_call(CSSBI_EID, CSSBI_SIGN_DATA, 0, 0, 0, 0);
            if (r.error == CSSBI_ERR_DENIED)
                uart_puts("[CaribeSecurity] privileged signing DENIED PASS\r\n");
            {
                static const uint32_t unsupported[] = {
                    CSSBI_VERIFY_IMAGE, CSSBI_KEY_GET_PUBLIC,
                    CSSBI_VERIFY_SIGNATURE, CSSBI_VERIFY_TOKEN,
                    CSSBI_GET_MEASUREMENTS, CSSBI_ROLLBACK_CHECK, 255
                };
                unsigned i, good = 1;
                for (i = 0; i < sizeof(unsupported) / sizeof(unsupported[0]); i++) {
                    r = sbi_call(CSSBI_EID, unsupported[i], 0, 0, 0, 0);
                    good &= r.error == CSSBI_ERR_NOT_SUPPORTED;
                }
                r = sbi_call(CSSBI_EID, CSSBI_GET_CAPABILITIES, 2, 0, 0, 0);
                good &= r.error == CSSBI_ERR_INVALID_PARAM;
                r = sbi_call(CSSBI_EID, CSSBI_KEY_GENERATE, 0, 0, 0, 0);
                good &= r.error == CSSBI_ERR_DENIED;
                r = sbi_call(CSSBI_EID, CSSBI_SIGN_ATTESTATION, 0, 0, 0, 0);
                good &= r.error == CSSBI_ERR_DENIED;
                if (good)
                    uart_puts("[CaribeSecurity] discovery ABI error paths PASS\r\n");
            }
        }
    }
    uart_puts("[CaribeSecurity] ORANGE: firmware root unverified; trusted attestation unavailable\r\n");
}

void caribe_security_policy(const char *command_line)
{
    static const char require[] = "security=require";
    const char *p = command_line;
    while (*p) {
        unsigned i = 0;
        while (*p == ' ' || *p == '\t')
            p++;
        while (require[i] && p[i] && require[i] == p[i])
            i++;
        if (!require[i] && (!p[i] || p[i] == ' ' || p[i] == '\t'))
            evidence.required_policy = 1;
        while (*p && *p != ' ' && *p != '\t')
            p++;
    }
    uart_puts(evidence.required_policy ?
        "[CaribeSecurity] policy=REQUIRE (development enrollment)\r\n" :
        "[CaribeSecurity] policy=PERMISSIVE\r\n");
}

void caribe_security_image(const char *name, uint32_t permission,
                           const void *payload, uint32_t size,
                           const uint8_t *manifest, uint32_t manifest_size)
{
    uint8_t subject[32] = {0}, nonce[32] = {0};
    uint8_t *digest = permission == CATKEY_PERM_KERNEL ?
                      evidence.kernel_sha256 : evidence.initrd_sha256;
    unsigned i;
    for (i = 0; i < sizeof(subject) - 1 && name[i]; i++)
        subject[i] = (uint8_t)name[i];
    if (name[i] || catkey_sha256(payload, size, digest) != 0)
        fail_closed("image measurement failed");
    if (manifest_size == 0 && !evidence.required_policy) {
        uart_puts("[CaribeSecurity] unsigned image measured: ");
        uart_puts(name);
        uart_puts("\r\n");
        return;
    }
    if (catkey_verify(manifest, manifest_size, development_key,
                      CATKEY_ROLE_DEVELOPMENT,
                      CATKEY_PERM_KERNEL | CATKEY_PERM_INITRD,
                      permission, CATKEY_KIND_IMAGE, subject, nonce,
                      payload, size) != CATKEY_OK)
        fail_closed("CatKey manifest/signature/image verification failed");
    evidence.verified_images |= permission;
    uart_puts("[CaribeSecurity] Ed25519/SHA-256 verified: ");
    uart_puts(name);
    uart_puts("; effective state remains ORANGE\r\n");
}

const caribe_security_evidence *caribe_security_get_evidence(void)
{
    return &evidence;
}
