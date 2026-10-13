# GitHub Restore Verification

Recorded 2026-10-13. Fresh HTTPS clones from the exclusively authorized
`h0nda1337` account, development branch `develop/syllable-native-v0.2`:

- XNU HEAD: `3a9c9e8412a68ce98b804217e07089f5a9686e13`.
- Runtime source/evidence HEAD: `3cd25bc70bdf0a5f0edc1498ed9154770f6edd27`.
- Restore directory: `F:/CaribeOS-Backups/syllable-futex-v0.10-20261013-restore`.
- Both HEADs match the pushed source commits and remote branch references.
- `git fsck --full` PASS in both clones. Informational dangling tag objects
  are not integrity failures and were not pruned.
- Both cloned working trees clean after verification.
- Full static checks PASS: XNU 3,574 and runtime 1,518 tracked files.
- Fresh preparation of the four pinned Syllable source sets yields byte-identical
  manifests compared with the tested original workspace.
- Fresh pinned Monocypher/Mbed TLS sources verify their declared commits.
- All 85 host unittest guards PASS again in the restored runtime.
- All three PowerShell guards PASS in the restored runtime, including actual
  concurrent disk-lock rejection and shared kernel forcing parameter binding.
- Protected technical tag unchanged locally, in the clone and on GitHub:
  XNU peeled commit `bf82ffc9849024fb38c99e1c2ed49961b82e9f4e`, runtime
  peeled commit `406f910d06891f30c866d284fbc98bde83f94e35`.
- Existing repository visibility remains PUBLIC, unchanged from the prior
  authorized publication. No new Actions runs on the development branch.

Pushes were ordinary fast-forwards to the development branch only, with no
force, tag mutation, binary Release, LFS or paid service enabled. This later
documentation-only commit records the completed restore test; it does not
change the verified kernel source or artifacts.

The fresh restore test does not claim a fresh kernel link or QEMU boot from
the clones. The actual six-boot matrix, fifteen process targets and forced
eleven-unit/thirteen-artifact reproducibility proof were executed in the
original F: workspace and are retained separately in this evidence directory.
