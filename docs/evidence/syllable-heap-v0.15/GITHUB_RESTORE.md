# GitHub source restoration verification

Verified 2026-10-14 after non-force pushes to develop/syllable-native-v0.2.

```text
XNU:     5565d9cb07ee56e03906f9e7423bdcdc0c7dc405
Runtime: 912725ad52dfcedfcd1dde114f71e6cb7bbf5573
```

Both HTTPS remotes belong to h0nda1337; gh confirmed that active account.
git ls-remote confirmed both branch heads and the unchanged protected tag:

- XNU tag object 28f5ff9cb066c89eae3450deaa0c439ba5f16b11,
  target bf82ffc9849024fb38c99e1c2ed49961b82e9f4e.
- Runtime tag object 57bebdbf0d52aa7be5f4fe36b0fa11610f4c28d2,
  target 406f910d06891f30c866d284fbc98bde83f94e35.
- gh run list returned no runs for either development branch after the pushes.

Fresh single-branch/no-tags GitHub clones were made under
F:/CaribeOS-Backups/syllable-heap-v0.15-20261014-141516-r/:
xnu-2050.48.11 and r/c. Only the protected technical tag was explicitly fetched.
Both restored HEADs matched; git fsck --full returned success. Unreferenced
tag-object diagnostics were informational; no objects were pruned.

Full static validation passed: 3574 XNU and 3931 runtime tracked files.
Monocypher 0d85f98c9d9b0227e42cf795cb527dff372b40a4 and Mbed TLS
e185d7fd85499c8ce5ca2a54f5cf8fe7dbe3f8df were freshly prepared and verified.
Seven graphical/Syllable source preparations and the separate musl heap
preparation regenerated eight source records identical to the tested tree.
The local cached musl archive was copied only after checking its official pin;
all 2697 original inputs, the routing patch and original notices were checked.

The clones passed 247 host tests, three PowerShell runner guards and parsing
of all 37 tracked PowerShell scripts. Both working trees stayed clean.

This proves source restoration and the stated static/host/source checks.
It does not claim a complete kernel/musl/GNU/FreeType rebuild or QEMU boot
from the clones. The actual guest/rebuild matrix was run in the primary tree.
No binary Release, main/tag/visibility change or paid service was enabled.
