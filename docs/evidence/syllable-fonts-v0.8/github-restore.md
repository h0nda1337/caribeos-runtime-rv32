# GitHub Source Restore

Verified 2026-10-13 from fresh GitHub clones on F:, not local repository copies.

| Repository | Verified development source commit |
| --- | --- |
| XNU | `b7ca002a3668c65545a3ba34ce1c444cf188a453` |
| Runtime | `8997accbec7eb894b7c9155c4bb7febb6df04876` |

Both clones pass `git fsck --full`; working trees are clean. Informational
dangling annotated tags are not corrupt objects and were not pruned.
Full static/source/license validation passes: XNU 3569 files, runtime 1027
files at the source commits above. The protected technical tag was explicitly
fetched unchanged into both no-tags clones. The runtime remote branch matched
the expected commit using `git ls-remote`.

The fresh dependency preparers reproduce four exact workspace manifests:

| Manifest | SHA-256 |
| --- | --- |
| FreeType/Vera | `9665167c9991832872fb87ae20a54b63a90bd5859ea2e75964a8b21954851159` |
| Native Syllable APIs | `87fd915ecb1338c84428eb52ea771e7089e0d016f344e9870556f5fd3c4d6a6e` |
| String | `30a23aacb5073e64f0d648431f67ef56d2a629c27fe5e472356ebe893f9e6afe` |
| Message | `17a97a146424532b67d2e8490c18fd0299b77cafc7bc9416f358e01bcf061ba3` |

The full 48 host-only tests pass in the restored runtime. CatKey's 14 tests
also require the existing pinned Monocypher/Mbed TLS inputs; preparing them
resolved the initial missing-dependency compile failure without code changes.
The fresh source-only preparation sequence was:

```powershell
python scripts/prepare-font-deps.py
python scripts/prepare-syllable-native.py
python scripts/prepare-syllable-string.py
python scripts/prepare-syllable-message.py
python scripts/prepare-security-deps.py
python -m unittest discover -s tests -v
```

This verifies Git integrity, licensed source recovery, dependency pins and
host guards. It is not a fresh image/kernel rebuild or a QEMU boot from the
restore directory. Actual boot and exact forced rebuild evidence remains in
the separate retained workspace matrix, not relabeled as restore boot proof.

Local clone/log directory:
`F:/CaribeOS-Backups/syllable-fonts-v0.8-20261013-restore`.
No binary Release, force push, stable-branch change, paid service or new
Actions run was enabled. GitHub reports no runs on this development branch.
