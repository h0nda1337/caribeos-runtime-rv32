# GitHub Restoration Check

Recorded 2026-10-13 after the actual TCB/native ELF TLS matrix passed.

## Verified Source Heads

- XNU: `3a9c9e8412a68ce98b804217e07089f5a9686e13`, unchanged.
- Runtime: `a72a47702a48f284ea057c7ac9d37f2ace850a5e`.
- Branch: `develop/syllable-native-v0.2` in both repositories.
- Authenticated active account was exactly `h0nda1337`.
- Runtime push was fast-forward, with tag following disabled. No force,
  main-branch change, new Release, visibility change or billable service.
- Both repositories were already PUBLIC and remained so; this operation
  did not convert a private repository or publish new binary assets.

## Fresh Restore

Both repositories were cloned directly from GitHub into a new paired
`syllable-tcb-v0.11-20261013-restore` directory on F:. The verified technical
tag was fetched separately, not recreated or moved. Both `git fsck --full`
runs exited 0; their informational dangling tag objects were not pruned.

The restored runtime passed 108/108 actual host tests and three actual
PowerShell guards. Public-tree validation passed for 1,812 runtime and
3,574 XNU tracked files. Both working trees remained clean.

Four Syllable preparation scripts regenerated the pinned decorator/native
API/String/Message manifests byte-identically. Original Monocypher and
Mbed TLS source revisions were also freshly fetched and verified.

This restore check did not rebuild a new kernel, musl or GNU toolchain,
or claim another QEMU boot from the clones. Actual QEMU and byte-identical
artifact evidence belongs to the working-tree matrix recorded separately.

Technical tag targets remain `bf82ffc9849024fb38c99e1c2ed49961b82e9f4e` (XNU)
and `406f910d06891f30c866d284fbc98bde83f94e35` (runtime). Neither tag changed.
