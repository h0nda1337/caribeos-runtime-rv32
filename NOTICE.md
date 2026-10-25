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

The original TCB/TLS probe, assembly fixture and evidence tooling are runtime
BSD-2-Clause integration code. They include unmodified musl 1.2.5 ABI headers
and link its genuine MIT-licensed libc; they do not relicense musl. This
dependency checkpoint is not a complete pthread or thread-safe libc port.

The optional Thread profile additionally builds the original libsyllable
`util/thread.cpp` and unchanged `util/thread.h`, `util/exceptions.h`, and
`atheos/time.h` at the pinned Syllable revision. The public Thread header
credits Henrik Isaksson (2002) and LGPL version 2; thread.cpp has no per-file
banner, so its component/header license basis is explicit in sources.json.
Original notices and the complete component COPYING.LIB are retained.
`thread-rv32.patch` remains LGPL-2.0-only, not runtime BSD: it replaces Linux
process kill with actual native thread cancellation/join and propagates errors.
The independently written lifecycle/clock/TCB integration and tests are
BSD-2-Clause. This does not relicense original Syllable, musl, GNU C++ or XNU.
No complete Looper/AppServer or threaded libc is claimed.

The optional Queue profile builds the original LGPL-2.0-only Syllable
`util/messagequeue.cpp` and unchanged public `util/messagequeue.h` at the
same pinned revision, retaining Kurt Skauen's copyright and full notices.
Its narrow tail/lifecycle patch remains LGPL, not runtime BSD. The
independent adapter routes ports through XNU native worker IPC without
relicensing Syllable, GNU C++, musl, OpenSBI/SecureSBI or APSL XNU.
Workers do not allocate/decode Message objects or use threaded stdio here;
Looper/AppServer and the authentic complete desktop remain required.

The optional heap profile uses a separately built genuine musl 1.2.5
allocator with unchanged mallocng/futex-lock sources and full original
COPYRIGHT. Its narrow RV32 VM-routing patch remains MIT, not runtime BSD;
see ports/musl. Independently written scope/VM integration and probes keep
their original BSD/APSL ownership boundaries. Syllable Message/Queue/Thread
stay LGPL and GNU libraries retain their own terms. This does not relicense
any external component or implement complete pthread/stdio/GNU threading.

The optional Locker profile uses the genuine LGPL-2.0-only Syllable
`util/locker.h` and unchanged native thread interface at the pinned Syllable
revision. Its narrow LGPL patch initializes the owner and removes an unused
obsolete debug include, preserving all original notices and locking algorithms.
The independently written RV32A atomic, native-thread identity and raw-TCB
semaphore/TCB adapters are BSD-2-Clause, not copies of upstream kernel code.
They do not relicense Syllable, musl or XNU, or implement Looper/AppServer.

The event-dispatch compilation bring-up retains ten pinned original
Handler/MessageFilter/Looper and platform-header inputs under LGPL-2.0-only.
Both native compilation patches retain LGPL and complete original notices.
Only the independently written source-preparation/audit/host tools are BSD.
Successful standalone compilation is not a linked/running Looper, AppServer,
node-monitor backend or complete desktop; no external component is relicensed.

The separate experimental Looper runtime adaptation and private decoder-header
patch remain LGPL-2.0-only with all original Syllable notices. Independently
written native wake/diagnostic/context adapters, build tools and the test
application are BSD-2-Clause only as classified in the runtime scope manifest.
The native exception-context variant compiles unmodified GNU libsupc++
eh_globals.cc and eh_alloc.cc under their GPL terms and GCC Runtime Library
Exception 3.1; complete COPYING3/COPYING.RUNTIME are retained in prepared inputs.
It does not relicense GNU, Syllable, musl or XNU, enable complete GNU threading,
or publish a new binary Release. Running dependency gates is not a complete
AppServer/Desktop port.

The separate experimental Messenger profile additionally compiles the complete
original Messenger implementation and enables original Message reply and
return-address methods, without enabling Variant. Its native platform/deadline
and failure-lifetime patch remains LGPL-2.0-only, not BSD, with original notices
and complete COPYING.LIB preserved. Only the independent source preparer,
probe and host guards carry original runtime BSD-2-Clause terms. This does not
relicense Syllable, GNU, musl or XNU or constitute a complete AppServer/Desktop
or a new binary Release.

The separate experimental Variant profile additionally compiles the original
LGPL-2.0-only Variant implementation/header and enables original Message typed
value methods. Its derived four-file patch retains LGPL and all original
notices; it is not runtime BSD. Only the independent preparer, probe, runners,
verifier and host guards are classified original BSD-2-Clause code. This does
not relicense Syllable, GNU, musl or XNU, implement the actual GUI/AppServer,
or publish a new binary Release.

The client-platform include patches retain original Syllable LGPL-2.0-only
terms and notices. The new compilation auditor and scoped server header
umbrella are independently written BSD-2-Clause integration code, not kernel
or GUI implementations. Original server sources remain unmodified inputs;
their mixed historical license notices require review and are not reassigned
to BSD. No external component is relicensed and no binary Release is added.
