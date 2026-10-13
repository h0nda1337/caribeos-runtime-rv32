# GitHub Locker checkpoint restoration

Verified 2026-10-13 using active account `h0nda1337`, authenticated HTTPS.
Only the existing `develop/syllable-native-v0.2` runtime branch was pushed,
fast-forward without force or tags. Both repositories already were PUBLIC;
visibility and main branches were not changed. No new binary Release,
Packages, Codespaces, billing settings or paid service was enabled.
`gh run list` returned no Actions runs for this development branch.

Fresh single-branch clones came directly from GitHub, not from local
repositories, into
`F:/CaribeOS-Backups/syllable-locker-v0.12-20261013-restore/`.

| Repository | Expected and observed feature HEAD |
|---|---|
| caribeos-xnu-rv32 | `3a9c9e8412a68ce98b804217e07089f5a9686e13` |
| caribeos-runtime-rv32 | `b54465c63fefcce9bf0f13c3ed01d216d875c8f7` |

Both fresh clones passed `git fsck --full` with exit 0. Informational
dangling tags were not corruption and were not pruned. Working trees
remained clean after verification. Static/public-license validation passed:
3,574 tracked XNU files and 2,181 tracked runtime files.

The original technical tag was fetched without modification and retained
its expected peeled targets: XNU `bf82ffc9849024fb38c99e1c2ed49961b82e9f4e`
and runtime `406f910d06891f30c866d284fbc98bde83f94e35`.
Remote branch and tag hashes were also checked with `git ls-remote`.

Actual fresh-clone verification reran all **136 Python host tests** and the
three PowerShell parameter/build-log/disk-ownership guards successfully.
The decorator, native APIs, String, Message and Locker preparers regenerated
all five source manifests byte-identically to the working project.
Monocypher and Mbed TLS source preparation verified their pinned revisions.

This proves source restoration, host checks and deterministic source
preparation, not a fresh kernel/musl/GNU build or QEMU boot from these
clones. Real QEMU and forced compilation evidence is recorded separately
in [VERIFICATION.md](VERIFICATION.md). This restoration targets the feature
commit above; the following documentation-only commit records the results.
