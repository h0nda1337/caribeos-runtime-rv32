# GitHub source restoration verified

Verified 2026-10-14 using fresh HTTPS single-branch clones, not copies of the
working trees. The authorized active account was h0nda1337. Both existing
repositories remained PUBLIC; only develop/syllable-native-v0.2 advanced by
non-forced pushes. No main/tag/visibility/Release/service setting changed;
branch Actions lists were empty after publication.

Published and restored feature HEADs:

- XNU: `bded0dbde1779c86c2a47c19868e4183a8ba40a4`
- Runtime: `3a571c703d178cede1ef9b825374ba64086b8843`

Fresh paired source root:

```text
F:\CaribeOS-Backups\syllable-queue-v0.14-20261014-112519-r
  xnu-2050.48.11
  r\c
```

The clones fetched only the preserved technical tag explicitly after cloning
without tags. Its unchanged object/target remain:

- XNU: `28f5ff9cb066c89eae3450deaa0c439ba5f16b11` /
  `bf82ffc9849024fb38c99e1c2ed49961b82e9f4e`
- Runtime: `57bebdbf0d52aa7be5f4fe36b0fa11610f4c28d2` /
  `406f910d06891f30c866d284fbc98bde83f94e35`

Both fresh clones had the expected HEAD, clean tracked trees and
`git fsck --full` exit 0. Unreferenced tag objects reported by fsck are
informational; no objects/history were pruned. Full static checks passed:
3574 XNU and 3228 feature-runtime tracked files, including license/SPDX,
third-party scope, NOTICE and public-tree validation. Last-commit Gitleaks
scans passed before push, as did whitespace checks.

The restored runtime prepared the pinned Monocypher/Mbed TLS dependencies
and all seven graphics/Syllable source profiles. Every regenerated source
record was byte-identical to the original verified workspace: decorator,
native APIs, String, Message, Locker, Thread and MessageQueue. The restored
paired tree then passed all 206 host tests, three actual PowerShell guard
scripts and parsing of all 34 tracked PowerShell files, without changing
tracked files. These host tests include fixtures and are not guest proof.

No complete kernel/musl/GNU/FreeType build or QEMU run from the fresh clones
is claimed. Actual guest/build/rebuild evidence is the separately retained
v0.14 matrix from the original F: workspace. This restoration validates the
published source checkpoint and its dependency preparation/host guards,
not a second full binary reproduction or completion of the desktop goal.
