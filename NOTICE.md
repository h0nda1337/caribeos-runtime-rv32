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

The public Developer Preview places verified corresponding source for its Bash
and musl binaries beside the binary asset as
`caribeos-tranche-201-corresponding-source.zip`. See `THIRD_PARTY.md` and
`docs/PUBLIC_LICENSE_REVIEW.md` for versions, hashes, and redistribution
boundaries.

This is a technical notice, not legal advice.

The experimental graphics branch builds the authentic Syllable AppServer
DefaultDecorator and WindowDecorator under LGPL-2.0-only. Kurt Skauen and
Syllable Team notices are preserved. The CaribeOS Layer/interface adapter
is also LGPL-2.0-only, explicitly excluded from the runtime BSD allowlist.
See [Syllable port](ports/syllable/README.md) and its complete COPYING.LIB.
The public-domain font8x8 retains Daniel Hepper/Marcel Sondaar/IBM notices.
This source update does not publish new binaries or alter Tranche 201 assets.

The native Syllable message-port adapter and fixed-width IPC ABI are original
CaribeOS integration code under BSD-2-Clause. The pinned Syllable `msgport.h`
and audited Message/areas sources keep their original LGPL-2.0-only notices;
they are not relicensed by this adapter. Native ports run inside XNU, whose
APSL 2.0 terms and file notices remain unchanged. Neither X11 nor Wayland is
a dependency of this native path. A complete AppServer/Desktop is not yet
claimed by the message-port gates.

CaribeSecurity, CatKey tools, protocol headers, and security build/test wrappers
are original CaribeOS integration code under BSD-2-Clause when listed in the
runtime scope manifest. Ed25519 verification uses unmodified Monocypher 4.0.2
(BSD-2-Clause OR CC0-1.0); SHA-256 uses unmodified Mbed TLS 3.6.5 (the
Apache-2.0 option). Their upstream notices must accompany redistributed code
or binaries. The runtime license does not relicense either library.

SecureSBI is a separate, modified OpenSBI source tree, not a CBX payload.
OpenSBI's original copyrights and file-level licenses remain applicable.
New CaribeSSBI code carries its own original-code BSD-2-Clause notices.
No production private keys, proprietary Motorola firmware, or Xbox code are
included. Experimental software verification is not hardware attestation.
