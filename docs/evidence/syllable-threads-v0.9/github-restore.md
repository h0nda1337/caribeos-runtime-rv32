# GitHub Source Restore

Verified 2026-10-13 from new GitHub clones on F:, not local repository copies.

| Repository | Verified development source commit |
| --- | --- |
| XNU | `b7a38385d13d1de15c068b2b4ffb01217a8bacfa` |
| Runtime | `1f26041bbf21c7107a750b1a919581c3291454ca` |

The runtime feature commit is `f90fed73be7ebb3f0c5d9d9512b2ecf8a98fa758`.
The subsequent commit makes a host PowerShell guard portable to this paired
`xnu`/`runtime` clone layout. The first restored attempt exposed the old path
assumption; fetching the actual fix from GitHub resolved it without modifying
the restored sources manually. No kernel or guest artifact changed for that fix.

Both repositories pass `git fsck --full` with clean working trees. Informational
dangling annotated tags were not pruned. Both protected technical tags were
fetched explicitly and their original objects and peeled commits match the
workspace and GitHub. Remote branch HEADs were verified with `git ls-remote`.
Full static/source/license checks pass: XNU 3573, runtime 1212 tracked files.

Fresh dependency preparation reproduces all four workspace manifests exactly:

| Manifest | SHA-256 |
| --- | --- |
| FreeType/Vera | `9665167c9991832872fb87ae20a54b63a90bd5859ea2e75964a8b21954851159` |
| Native Syllable APIs | `87fd915ecb1338c84428eb52ea771e7089e0d016f344e9870556f5fd3c4d6a6e` |
| String | `30a23aacb5073e64f0d648431f67ef56d2a629c27fe5e472356ebe893f9e6afe` |
| Message | `17a97a146424532b67d2e8490c18fd0299b77cafc7bc9416f358e01bcf061ba3` |

Pinned Monocypher and Mbed TLS inputs were also prepared. All 62 host-only
tests pass in the restored runtime. Both PowerShell build guards pass there:
explicit logged failure handling and actual kernel parameter binding. They
launch no QEMU instance and establish no guest execution claim.

Restore directory:
`F:/CaribeOS-Backups/syllable-threads-v0.9-20261013-restore`.
The scope is source recovery, dependency pins and host guards, not a new
kernel/image build or QEMU boot from the clone. Actual boot and forced
byte-identical rebuild proof remain in the separate retained workspace matrix.
The final user runner uses QEMU's default CPU; the three strict RV32IMACSU
matrix runs are separate and are not inferred from that default-CPU run.

Only the authorized existing development branches were pushed, without force.
Repository visibility was left unchanged. No binary Release, paid service or
new Actions run was enabled; GitHub reports no runs on either development branch.
