# GitHub source restoration v0.13

Verified 2026-10-13 after fast-forward pushes on develop/syllable-native-v0.2.

- XNU HEAD: `212e43ca5b2e35c3b1d6e788c953b0857cd2bc62`.
- Runtime feature HEAD: `a43236f8c41b43ed569d6b3bf79423e9774186e8`.
- Fresh single-branch, no-tag clones under
  `F:/CaribeOS-Backups/syllable-thread-v0.13-20261013-r/`.
- The protected technical tag was explicitly fetched and is unchanged:
  XNU `28f5ff9cb066c89eae3450deaa0c439ba5f16b11`, runtime
  `57bebdbf0d52aa7be5f4fe36b0fa11610f4c28d2`.
- Both clones have clean tracked trees and git fsck --full exit 0.
  Unreferenced tag objects are informational and were not pruned.
- Static validation: XNU 3,574 files; runtime 2,623 files; PASS.
- Pinned Monocypher and MbedTLS sources were prepared using the existing
  dependency recipe before security host tests. The first host attempt
  correctly failed because those sources were absent from the fresh clone;
  after preparation the complete suite passed, with no test removed/skipped.
- All 173 host unit tests and all three actual PowerShell guards PASS.
- Graphics decorator, native API, String, Message, Locker and Thread source
  preparation ran in the restored checkout. All six sources.json records
  are byte-identical to the verified primary checkout.
- Upstream licenses/notices survive; the new Thread patch remains LGPL.

This is source/host restoration verification. No fresh complete kernel,
musl/GNU C++/FreeType build or QEMU boot was performed from these clones.
Actual guest and byte-identical compiler evidence comes from the primary
checkout's separately retained final matrix and rebuild records.

The account is h0nda1337. Existing public visibility, main and technical
tags were not changed; no force push, binary Release or paid service was used.
No development-branch Actions runs were listed after publication.

The following documentation-only commit adds this audit record; it does not
change the feature sources or artifacts proven at the feature HEAD above.
