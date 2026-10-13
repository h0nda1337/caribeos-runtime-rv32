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

The native Syllable message-port/shared-area adapters and fixed-width IPC/area
ABIs are original
CaribeOS integration code under BSD-2-Clause. The pinned Syllable `msgport.h`
and `areas.h` plus audited Message sources keep their original LGPL-2.0-only notices;
they are not relicensed by this adapter. Native ports run inside XNU, whose
APSL 2.0 terms and file notices remain unchanged. Neither X11 nor Wayland is
a dependency of this native path. A complete AppServer/Desktop is not yet
claimed by the message-port or shared-area gates.

The optional native C++ development profile builds GNU libstdc++ 15.1.0
against RV32-musl from pinned unmodified GNU sources. GNU runtime files keep
their GPL terms and the GCC Runtime Library Exception 3.1 where applicable;
neither the library nor compiler headers/CRT/libgcc are relicensed BSD.
Original CaribeOS build controls and its independent test application remain
BSD-2-Clause. This profile publishes source/build controls, not a new binary
Release. Current single-thread/emulated-TLS limits are documented explicitly.

The genuine libsyllable os::String implementation and the separate RV32
source patch retain LGPL-2.0-only. Original Kurt Skauen and Syllable Team
notices remain intact; the public String header is unchanged apart from
normalized line endings. An isolated existing Font UTF-8 helper keeps its
original LGPL notices and is not a substitute Font engine. The original
preparer and independent test application are BSD-2-Clause; they do not
relicense the library, helper or patch. No new binary Release is published.

The additional genuine libsyllable Message data-core source/header patch and
unchanged Flattenable/typecodes/geometry headers also retain LGPL-2.0-only.
Original Kurt Skauen and Syllable Team notices remain intact. The bounded
profile explicitly excludes Looper/Handler/Variant delivery; it is not a
complete AppServer library. The original exact-length native receive adapter,
source preparer and independent tests remain BSD-2-Clause, without relicensing
any Syllable input. Future binary distributions need exact corresponding
sources and relink materials; no new binary asset is published by this update.

The native counting-semaphore adapter is original BSD-2-Clause integration
code. Its pinned public Syllable semaphore header remains LGPL-2.0-only with
Kurt Skauen's original notices unchanged. The native XNU implementation remains
APSL 2.0; the runtime license does not relicense either external interface or
kernel. Counting semantics do not imply native GUI threads, recursive kernel
mutexes, reader/writer locks or a complete libsyllable/AppServer library.

The optional font dependency profile uses authentic unmodified FreeType
2.15.0 under the FreeType License, with upstream per-file exceptions intact.
This software is based in part on the work of the FreeType Team.
Bitstream Vera 1.10 font data retains its own complete Bitstream notices and
redistribution conditions. Neither FreeType nor the fonts is relicensed BSD.
Only the original build/preparer controls and independent probe are BSD-2-Clause.
See [font notices](ports/freetype/NOTICE.md). This is a dependency gate, not
the complete Syllable Font/SFont/AppServer implementation or a new binary Release.

CaribeSecurity, CatKey tools, protocol headers, and security build/test wrappers
and the independently written raw-thread UAPI/probe/evidence tools
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

The independently written private-futex probe and runner/host guards retain
the runtime's BSD-2-Clause terms. The corresponding native XNU scheduler
backend retains APSL-2.0. It adds no external Linux kernel code and does not
relicense musl, GNU or Syllable or claim pthread compatibility.
