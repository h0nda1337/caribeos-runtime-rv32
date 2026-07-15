# Notices

CaribeOS is an independent experimental project. It is not affiliated with,
endorsed by, or supported by Apple Inc.

Original CaribeOS runtime code identified by
`SPDX-License-Identifier: BSD-2-Clause` is Copyright (c) 2026 h0nda1337 and is
licensed under the BSD-2-Clause terms in `LICENSE`. The complete machine-readable
allowlist and reviewed exclusions are recorded in
`docs/RUNTIME_LICENSE_SCOPE.json`.

The BSD-2-Clause grant applies only to original CaribeOS runtime code in that
scope. It does not relicense external, derived, generated, mixed-provenance,
binary, or data files. Existing notices and file-level terms take precedence
for material outside that scope.

The companion XNU-CaribeOS kernel derives from Apple's open-source XNU
2050.48.11. It remains under APSL 2.0 and its file-level notices. Nothing in the
runtime `LICENSE` changes XNU's license or grants rights to macOS or proprietary
Apple SDK material.

GNU Bash remains under GPL-3.0-or-later. musl retains its MIT-style terms.
OpenSBI, QEMU, GCC, binutils, make, and all other external components remain
under their respective licenses. CaribeOS build wrappers and integration code
may be BSD-2-Clause when listed in the scope manifest, but that does not change
the license of the component they build or invoke.

The public Developer Preview must place verified corresponding source for its
Bash and musl binaries beside the binary assets. See `THIRD_PARTY.md` and
`docs/PUBLIC_LICENSE_REVIEW.md` for versions, hashes, and redistribution gates.

This is a technical notice, not legal advice.
