# CatKey v1 Wire Format and Key Policy

CatKey is a signed record format, not a new cryptographic primitive. It uses
standard Ed25519 (not Ed25519ph or Monocypher's alternative EdDSA) over a
160-byte body. Image content is bound by SHA-256, length, subject, and role.
The verifier is `security/catkey.c`; the host signer is `tools/catkey.py`.

## Fixed Wire Record

Exactly 224 bytes, integers unsigned little-endian, no padding or variable
length parsing. Short and oversized inputs fail. All body fields are signed.

| Offset | Size | Meaning |
|---|---|---|
| 0 | 8 | ASCII `CATKEY1` followed by NUL |
| 8 | 4 | Format version 1 |
| 12 | 4 | Kind: IMAGE 1, TOKEN 2 |
| 16 | 4 | Key role |
| 20 | 4 | Permission mask |
| 24 | 4 | Rollback generation; MUST be zero until persistent policy exists |
| 28 | 4 | Payload length |
| 32 | 32 | Subject (zero-padded 1..31 ASCII image label, or opaque token identity) |
| 64 | 32 | SHA-256 payload digest; tokens bind the empty payload |
| 96 | 32 | Ed25519 raw signer public key |
| 128 | 32 | Challenge nonce; images use zero, token verifier requires caller's expected nonce |
| 160 | 64 | Standard Ed25519 signature over bytes 0..159 |

Magic, version, and kind provide signed domain separation. An image record
cannot be used as a token. Image labels in CBX are `kernel.elf` and
`initrd.img`; manifests are HFS+ `/kernel.catkey` and `/initrd.catkey`.

## Trust Is External to the Record

The supplied signer key is compared against a separately enrolled public key.
A correctly self-signed record is NOT trusted. The caller also supplies the
trusted key role, allowed permissions, required permissions, kind, subject,
and challenge. Signed role or permission fields never authorize themselves.
An all-zero public anchor explicitly means no enrollment and is rejected
before signature verification; it is never treated as an Ed25519 public key.

| Role | Value | Developer-tool policy |
|---|---|---|
| Firmware | 1 | Firmware permission `8` only; no M-mode signer exists |
| Development | 2 | Kernel `1`, initrd `2` |
| Maintenance | 3 | Maintenance `4` only |
| Owner | 4 | Kernel, initrd, maintenance; no firmware or attestation authority |
| Attestation | 5 | No supported v1 signing use; DENIED by role policy |

The generic C verifier enforces the caller's externally supplied role and
permission allowlist. CBX only enrolls a DEVELOPMENT key with kernel/initrd
permissions. These host role options are not firmware capabilities. Tokens
can be created and verified on the host and through the reusable C API;
they do not unlock privileged SBI operations in this phase.

## Developer Workflow

Use a PRIVATE directory outside every Git worktree (including ancestors).
This tool deliberately emits plaintext development-only PEMs; protect that
directory with host ACLs. Production signing must use a separate controlled
service/HSM and must not embed master private keys in firmware, PHP, Git,
release assets, generated trust headers, or logs. Public enrollment is raw
32-byte Ed25519 data; headers contain public material only.

```powershell
python tools/catkey.py keygen --private F:\CaribeOS-DevKeys\dev.pem --public build/dev.pub
python tools/catkey.py enroll-header --public build/dev.pub --output build/dev-trust.h
make all DEV_TRUST_HEADER=build/dev-trust.h
python tools/catkey.py sign-image --private F:\CaribeOS-DevKeys\dev.pem --record build/kernel.catkey --image ..\..\xnu-2050.48.11\BUILD\obj\RELEASE_RISCV32\osfmk\RELEASE\xnu-caribeos-rv32-full-stage0.elf --subject kernel.elf --permission kernel
```

Repeat for initrd with its image, subject `initrd.img`, and permission `initrd`.
Insert both records only into an isolated development HFS+ disk, then use
`security=require`. The automatic runner performs these steps without
altering the ordinary disk. Calling `make all` without DEV_TRUST_HEADER resets
enrollment to zero and rebuilds affected objects; it does not retain an old key.

Signing is deterministic for identical keys and record inputs. Key generation
is intentionally random. Token identity and nonce use exactly 64 hex digits;
nonce quality and one-time consumption are the issuer/verifier's responsibility.

## Limits and Next Format

v1 has no wall-clock expiry, persistent one-time-token database, certificate
chain, revocation list, multikey enrollment, or rollback storage. Never
interpret it as a production remote authorization protocol. A signature and
nonce check alone do not stop replay unless the verifier tracks consumption.
Hardware identity is unavailable in QEMU and no device identity is fabricated.
Production support requires a new version for explicit issuer/audience,
expiry, key ID, and policy generation, plus protected counters and enrollment.
Do not silently reinterpret v1's reserved-zero rollback field.
