# GitHub Source Restore

Verified 2026-10-13 from new single-branch clones under
`F:\CaribeOS-Backups\syllable-sync-v0.7-20261013-restore`.

- XNU HEAD: b7ca002a3668c65545a3ba34ce1c444cf188a453.
- Runtime HEAD: 3d524d1f297a9d3b18841a4de8e74bb600ba9044.
- Both cloned from the authorized h0nda1337 repositories, with fsck --full PASS.
- Full static/license validation: XNU 3,569 and runtime 875 tracked files PASS.
- Technical tag unchanged: XNU target bf82ffc9849024fb38c99e1c2ed49961b82e9f4e;
  runtime target 406f910d06891f30c866d284fbc98bde83f94e35.
- Fresh native/String/Message preparation fetched the pinned Syllable inputs
  and reproduced all three sources.json hashes exactly against the workspace.
- All 20 host-only source/profile/evidence guard tests passed from the clone.
- No Actions runs were present on either development branch after these pushes.

This test verifies remote source recovery, provenance regeneration and host
guards. It does **not** claim the fresh clones were fully rebuilt or booted in
QEMU; the kernel/runtime matrix and exact rebuild were performed in the working
trees and are retained separately. No binary Release or technical tag changed.
The subsequent documentation-only commit can reference these immutable source
checkpoint commits without rewriting or amending them.
