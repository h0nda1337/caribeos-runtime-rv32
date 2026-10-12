# CaribeSecurity v0.1: Local Verification Evidence

Date: 2026-10-12. Windows/MSYS toolchain, QEMU `virt` RV32, 256 MiB RAM.
These are new local integration results, not a rerun of every preserved
Tranche 201 kernel suite and not an independent security audit.

## Builds

Actual OpenSBI v1.9 modified SecureSBI firmware built with Clang/lld 22.1.4,
RV32IMAC + Zicsr/Zifencei, ILP32, FW_DYNAMIC. CBX built with RV32 GCC and
unmodified commit-pinned Monocypher 4.0.2/Mbed TLS 3.6.5. Full linked XNU
rebuilt with the kernel-owned entry stack and security handoff.

| Artifact | SHA-256 |
|---|---|
| SecureSBI `fw_dynamic.bin` | `1dfef056a1771c777c77379b627d2a725e7d5c2d69d386af27c7ae712a61ad33` |
| Default unenrolled CBX ELF | `b8d7cca7bc52c172947bee825f235f0438959db4a53bb2dc30021e2ccf0908ea` |
| XNU full-stage0 ELF | `244fbb75f1caca1aa2b7136cc2cb02cbbe0fa08ae7a08a0502e72fb0caeddf61` |
| Existing initrd | `9393175b120fc79d210d72da625f233fd17d369970391c394be0528061d017fa` |

An identical local rebuild preserved both SecureSBI firmware and default CBX
hashes. This checks the same checkout/toolchain, not cross-host bitwise
reproducibility. CatKey signing determinism is tested for identical inputs;
temporary key generation is random. No new binary Release was uploaded.

## Host Verifier: 14/14 PASS

SHA-256 known answers (empty, `abc`, million `a`); RFC 8032 standard Ed25519
empty-message vector; independent cryptography/OpenSSL signer against the
actual Monocypher C verifier; deterministic signatures; all 160 signed-body
byte mutations; all 64 signature-byte mutations; every truncation 0..223
and an appended byte; image/length/digest modifications; untrusted self-signed
key; subject binding; role-from-enrollment enforcement; token identity,
nonce, and insufficient permission rejection; nonzero rollback denial;
explicit empty-enrollment rejection and invalid-pointer input rejection.
Several of the 14 test methods iterate across all specified byte positions.

## QEMU: 17/17 PASS

Every case has its own `build/security-tests/NAME-serial.txt`. The runner
asserts success/rejection markers and checks that rejection never reaches
ELF entry, XNU, or the CBX command console.

| Case | Result |
|---|---|
| standard-orange-up | Stock OpenSBI, unsigned images, XNU/musl/Bash scripted boot, ORANGE |
| securesbi-orange-up | Modified M-mode firmware, CSSBI negotiation/error paths, ordinary boot, ORANGE |
| signed-standard-up | Required kernel/initrd Ed25519/SHA-256 validation with stock firmware |
| signed-securesbi-up | Required signatures and actual CSSBI calls with modified firmware |
| signed-securesbi-smp | Above plus two-hart kernel SMP Gate F |
| signed-securesbi-no-h | Explicit QEMU `-cpu rv32,h=false`; ordinary S-mode chain still boots |
| missing-manifest | RED, missing required manifest |
| modified-manifest | RED, changed signed subject byte |
| incorrect-signature | RED, changed signature byte |
| modified-kernel | RED, changed kernel payload byte |
| modified-initrd | RED, changed initrd payload byte |
| oversized-manifest | RED, 225-byte required manifest |
| oversized-permissive | RED, present oversized manifest is not treated as absent |
| empty-permissive | RED, present empty manifest is not treated as absent |
| bash-standard-up | Existing interactive Bash/process Gate 11, commands, fork/exec, exit/reap status 0 |
| bash-signed-securesbi-smp | Interactive Bash Gate 11 + SMP Gate F with required signatures |
| default-enrollment-cleared | Default CBX rejects the signed development disk after enrollment reset |

Custom firmware boots also assert version `0x00010000`, capability `7`,
SIGN_DATA DENIED, invalid capability index, reserved/unknown operations,
KEY_GENERATE DENIED, and SIGN_ATTESTATION DENIED. No successful boot advertises
GREEN or YELLOW. The loader and kernel independently clamp unverified roots;
this does not test resilience to arbitrary malicious firmware execution.

Selected real serial output:

```text
[CaribeSecurity] CaribeSSBI negotiated version=0x00010000 capabilities=0x00000007
[CaribeSecurity] privileged signing DENIED PASS
[CaribeSecurity] discovery ABI error paths PASS
[CaribeSecurity] Ed25519/SHA-256 verified: kernel.elf; effective state remains ORANGE
[CaribeSecurity] Ed25519/SHA-256 verified: initrd.img; effective state remains ORANGE
[boot-report] CaribeSecurity ORANGE root-unverified cssbi=0x00010000 reported-verified-images=0x00000003 required-policy=1
[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS
[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS
[process-gate-11] Gate 11 persistent interactive Bash PASS
```

## Explicitly Not Verified

Hardware root authentication, GREEN/YELLOW transitions, physical device
identity, protected entropy/keys, trusted attestation, persistent rollback,
token replay prevention, secure recovery execution, and VS guest mediation
are UNAVAILABLE or NOT_RUN, not PASS. Hypervisor/portal files are contracts
only. QEMU is not a security boundary against its host.

The historical `tranche-201-stage2-complete` tags are not moved. Normal CBX
is restored to unenrolled PERMISSIVE; its ordinary HFS+ image is refreshed
with the current XNU/initrd. Isolated signed test images retain only public
keys/signatures. Temporary private signing directories are removed; host
filesystem deletion is not a claim of cryptographic secure erasure.

## Build Issues Resolved

The native Windows GNU bare-metal linker cannot create OpenSBI's required PIE;
the dedicated firmware wrapper uses LLVM/lld after a real linker probe.
Clang exposed an uninitialized RV32 store-emulation union, now initialized.
A fully forced rebuild exposed CR characters in OpenSBI's generated Kconfig
dependencies, now normalized by the Makefile and the wrapper's cache repair.
The final 17-case run used a complete firmware rebuild, not old cached objects.
CBX's small-data sections now remain inside the loader extent. XNU's early
DTB parser no longer runs on or overwrites CBX's smaller stack/evidence.
