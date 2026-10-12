# CaribeSecurity v0.1

Development integration, not a production secure-boot system. No authenticated
BootROM, fuse key, protected entropy source, persistent rollback counter, or
trusted hardware identity is available in the current QEMU configuration.

## Implemented Chain

```text
Stock OpenSBI or SecureSBI (M-mode)
  -> CaribeBootX + CaribeSecurity (S-mode)
  -> HFS+ /kernel.elf and /initrd.img over virtio-blk
  -> XNU-CaribeOS (S-mode) -> Linux personality -> musl/GNU Bash
```

SecureSBI is the modified OpenSBI firmware itself. It occupies the existing
M-mode firmware slot. It is NOT a payload launched by another OpenSBI instance.
The `0x80000000-0x80200000` firmware reservation and SBI standard services
remain intact. Default boot is still `-bios default -kernel build/caribe_rv32.elf`.
The custom firmware path uses `-bios ../../securesbi/build/platform/generic/firmware/fw_dynamic.bin`.
Never use the obsolete `-bios build/caribe_rv32.bin` path.

## CaribeSSBI ABI 1.0

`include/uapi/caribe_ssbi.h` and SecureSBI's `include/sbi/caribe_ssbi.h`
must be byte-identical; the runner verifies this. Experimental EID
`0x08435342` is not an allocated standard or vendor EID. Register convention
follows SBI v0.2+: `a7=EID`, `a6=FID`, `a0..a5=arguments`, return
`a0=signed error`, `a1=value`. Discover via SBI BASE `probe_extension` first.
Version is `0x00010000` (major 1, minor 0); this loader requires that exact version.

| FID | Operation | Current behavior |
|---|---|---|
| 0 | GET_VERSION | Returns ABI version |
| 1 | GET_CAPABILITIES | `a0=word index`; index 0 returns `7`, index 1 returns `0`, other indices INVALID_PARAM |
| 2 | GET_SECURITY_STATE | Returns ORANGE plus SIMULATED and ROOT_UNVERIFIED flags |
| 3 | VERIFY_IMAGE | NOT_SUPPORTED; CBX performs software verification locally |
| 4 | KEY_GENERATE | DENIED; no firmware keys or entropy guarantees |
| 5 | KEY_GET_PUBLIC | NOT_SUPPORTED |
| 6 | SIGN_DATA | DENIED, never an arbitrary privileged signing oracle |
| 7 | VERIFY_SIGNATURE | NOT_SUPPORTED |
| 8 | VERIFY_TOKEN | NOT_SUPPORTED; reusable local CatKey C verifier is implemented |
| 9 | GET_MEASUREMENTS | NOT_SUPPORTED; CBX handoff carries software measurements |
| 10 | SIGN_ATTESTATION | DENIED; no trusted attestation key |
| 11 | ROLLBACK_CHECK | NOT_SUPPORTED; no persistent counter |

Capability bit N means FID N is implemented; DENIED reserved services do not
advertise capabilities. Values/errors are SBI-compatible: SUCCESS 0,
NOT_SUPPORTED -2, INVALID_PARAM -3, DENIED -4, INVALID_ADDRESS -5. Unknown
FIDs return NOT_SUPPORTED. Current discovery requests have no pointer inputs,
no shared mutable state, and are safe for concurrent harts. Future pointer
operations require a versioned, bounded request format and independent memory
validation; their ABI is deliberately not implemented yet.

## Policy and State

GREEN 0 requires an authenticated complete chain; YELLOW 1 requires an
authenticated owner-authorized chain. Neither state is reachable here.
ORANGE 2 is the operational state for both stock and custom QEMU firmware.
RED 3 halts before kernel entry when required verification fails.

CaribeSecurity probes firmware capabilities but ignores claimed trust states.
XNU clamps imported state to ORANGE independently. The presence of this
extension, a development signature, or a firmware-supplied GREEN value cannot
establish an authenticated root. Flags `0x100=SIMULATED`,
`0x200=ROOT_UNVERIFIED` remain distinct from state bits `0xff`.

Default PERMISSIVE measures unsigned images and boots normally. A supplied
manifest must verify even in permissive mode. The exact boot token
`security=require` requires both kernel and initrd manifests. Missing,
truncated, untrusted, incorrectly signed, or mismatched images halt in RED;
the CBX command console is not opened as a bypass. No automatic recovery
image is trusted or executed yet. A future recovery path needs its own
restricted enrolled key and independently verified image.

The command line, CBX public enrollment, and CBX itself are mutable developer
inputs, not hardware-enforced policy. An attacker controlling firmware/CBX
can replace the verifier or remove the boot token. Accordingly this is a
verified software mechanism, not an end-to-end anti-tamper guarantee.

## Handoff to XNU

The loader's existing boot-argument ABI is preserved. Reserved words 8..11
carry magic `0x31534543`, physical evidence address, size 128, and version 1.
`booter/caribe_security.h` defines the record: eight little-endian uint32
fields (magic, version, state, flags, CSSBI version, capabilities,
verified-image permission mask, required policy), followed by kernel hash,
initrd hash, and public-key SHA-256 ID (32 bytes each).

XNU validates alignment, size, version, and location within RAM in the loader
slot before copying the evidence. Its log intentionally says
`reported-verified-images`: these are loader reports, not independently
authenticated claims. XNU now switches to its own 64 KiB entry stack before
parsing the DTB, fixing the pre-existing overflow of CBX's 16 KiB stack.
No secrets or private keys cross this handoff.

## Build and Gates

Place sibling trees `securesbi`, `xnu-2050.48.11`, and
`caribeos-corrected-xnu-rv32imacsu/caribeos` under the same workspace. The
existing Windows MSYS cross toolchain remains in `msys64`. Use native Python
with the `cryptography` package; the recorded host version is 43.0.3. LLVM is
required for the native-Windows OpenSBI PIE build; CBX/XNU still use RV32 GCC.

```powershell
python scripts/prepare-security-deps.py
python scripts/test-caribe-security.py --build-kernel
```

The runner downloads commit-pinned unmodified crypto sources, builds the
actual firmware and CBX, and tests COPIES of the HFS+ image with QEMU
`-snapshot`. Its temporary development private key lives outside Git trees
and is deleted on completion; a crash still requires host cleanup. It resets
the ordinary CBX build to no enrollment and tests that reset. Never use this
temporary plaintext PEM mechanism for production master keys.

Logs remain separately named in `build/security-tests`. Host C-verifier tests
cover RFC 8032, SHA-256 vectors, cross-library signatures, every signed-body
and signature-byte mutation, all short lengths, wrong keys, roles,
permissions, identities, nonces, digests, and nonzero rollback rejection.
QEMU cases cover both firmware paths, signed images, no-H boot, SMP Gate F,
interactive Bash/process Gate 11, and mandatory rejection before ELF entry.
See [the evidence report](CARIBE_SECURITY_EVIDENCE.md) for the actual result.

For a normal persistent console using the custom firmware:

```powershell
.\scripts\qemu-rv32-console.ps1 -Bios ..\..\securesbi\build\platform\generic\firmware\fw_dynamic.bin
```

After the signing runner, its preserved public-only signed test artifacts can
also be used with `-BootElf build/security-tests/signed-booter.elf`,
`-DiskImage build/security-tests/signed.img`, and
`-Append "security=require process-gate-11"`. Do not mistake this for a
production enrollment.

## Engineering References

Implementation follows [OpenSBI](https://github.com/riscv-software-src/opensbi),
[SBI encoding](https://github.com/riscv-non-isa/riscv-sbi-doc/blob/master/src/binary-encoding.adoc),
and [Monocypher's standard Ed25519 module](https://github.com/LoupVaillant/Monocypher/blob/4.0.2/src/optional/monocypher-ed25519.h).
Monocypher publishes [quality assurance and audit information](https://monocypher.org/quality-assurance/);
that does NOT audit this new integration. SHA-256 is from
[Mbed TLS 3.6.5](https://github.com/Mbed-TLS/mbedtls/blob/v3.6.5/library/sha256.c).
The [Motorola Racer investigation](https://github.com/h0nda1337/motorola-edge-racer-progress/blob/main/reports/informe-desbloqueo-racer.md)
informs only identity-bound authorization and separation of permission from
signature validity. No proprietary code, binaries, identities, or certificates
were imported. Hypervisor and portal work are contracts, not deployed services.
