# CatKey Portal and Issuer Contract: Draft

Future human-facing portal:
`https://iwantacat.angelo.lol/obtain-a-catkey-portal.php`.
It was not contacted and the boot/tests do not depend on it. No portal,
issuer, network client, account authorization, or protected signer is
implemented by this change. PHP must never hold production signing keys.

## Separation of Responsibilities

The portal authenticates the person and submits a request to a separate
authenticated issuer service. The issuer enforces account/device entitlement
and a server-side permission allowlist, signs using an isolated HSM/service,
and records a redacted audit receipt. Requested privileges are not granted
merely because the client requested them or presented a valid signature.
Firmware/development/maintenance/owner/attestation keys remain separate.
There is no arbitrary "sign these bytes" endpoint.

Proposed issuer HTTPS API, not deployed:

| Endpoint | Contract |
|---|---|
| `POST /v1/challenges` | Authenticated request: protocol version, device identity evidence, audience, operation, payload hash if applicable; response: random 32-byte nonce, challenge ID, expiry, policy version |
| `POST /v1/authorizations` | Bound challenge ID/nonce, requested operation, issuer-validated identity and entitlement; idempotency key; response: signed record, public issuer key ID, policy version and receipt ID |
| `GET /v1/keys` | Public key metadata and independently authenticated rotation/revocation policy; never private material |

Use explicit bounded fields, canonical encoding, fixed algorithm IDs,
strict duplicate/unknown-field handling, maximum body sizes, authenticated
TLS, rate limits, and CSRF protection on browser actions. Reject expired,
reused, mismatched-audience, invalid-identity, or overprivileged requests.
Never log private keys, full authorization tokens, credentials, or unnecessary
device identifiers. Receipts contain hashes and nonsecret status only.

## Verifier Obligations

The local verifier authenticates the issuer public key from enrollment, checks
the signature, format, audience/subject, expected challenge, allowed key role,
requested permissions, lifetime, policy generation, and payload binding, then
atomically consumes the challenge before the authorized action. The server's
claim of identity is not hardware attestation on an untrusted platform.
ORANGE must deny actions that depend on hardware identity, protected secrets,
or trusted attestation even when a development token is valid.

CatKey v1 already provides signed kind, role, permissions, payload hash,
subject, and nonce. It does NOT encode issuer/audience/expiry or implement
persistent replay prevention. Thus v1 can exercise local developer crypto,
but cannot satisfy this production contract. Add a versioned format with
these fields and authenticated enrollment before connecting the portal.
Do not infer expiry from an unsigned JSON wrapper around a v1 token.

## Recovery and Revocation

Recovery must be scoped to a dedicated recovery image/action, never to
arbitrary signing or permanent policy disabling. Device-local enrollment and
rollback changes need physical-owner confirmation and protected persistence.
Lost-key recovery, offline operation, rotation windows, revocation, and audit
retention require a separately reviewed policy. Those features are pending;
the current RED path safely halts instead of claiming a secure recovery UI.
