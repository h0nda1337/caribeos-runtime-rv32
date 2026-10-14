# Syllable Source Patches

`string-rv32.patch` modifies genuine libsyllable `util/string.cpp` at commit
`579e480a005321cc320e7e355e8dff398b689be8`. The patch and resulting source are
LGPL-2.0-only, not BSD-2-Clause. Kurt Skauen's complete original notice is
preserved; the dated CaribeOS modification notice identifies the changes.
The complete applicable license is in `../COPYING.LIB`.

The public String header remains unchanged after line-ending normalization.
The preparer verifies SHA-256 of all normalized upstream inputs before applying
this versioned patch. It extracts only the existing byte-length helper from
the pinned Font header, preserving both Kurt Skauen and Syllable Team notices.
That helper is not a Font implementation or a Unicode validator.

The patch fixes empty/all-space reverse-trim underflow, uses unsigned ctype
arguments, supplies explicit musl/standard headers, removes duplicate class
qualification, and replaces reused va_list/VLA formatting with copied va_list,
two-pass bounded allocation and strong failure preservation. Successful
formatting now retains embedded NUL bytes instead of truncating them. Formatting
errors raise std::runtime_error; allocation errors retain normal GNU semantics.

Original and modified sources, unchanged public header, helper and full license
are retained in `build/syllable-string/`. Application objects, the separate
String archive and GNU archive permit relinking; a future binary distribution
must provide these exact materials and instructions. This source-only update
does not release new binaries or expand Tranche 201's old source asset.

`message-rv32.patch` modifies the same pinned revision's genuine Message
source/header under LGPL-2.0-only, retaining all original notices. It compiles
an explicit data-core-only profile, not complete Looper/Handler/Variant delivery.
Its bounded parser, alignment and lifetime changes are described in
[Message core](../../../docs/SYLLABLE_MESSAGE_CORE.md). The unsupported methods
are absent rather than implemented as success-returning stubs. Exact upstream
and adapted sources plus the full license remain in build/syllable-message.

`locker-rv32.patch` adapts the genuine inline `util/locker.h` at that same
revision under LGPL-2.0-only. It initializes the previously uninitialized
owner to -1 and removes an unused obsolete `sys/debug.h` include.
Original recursive ownership, atomic count and semaphore wakeup algorithms
and Kurt Skauen's full notice remain unchanged. Original/adapted headers,
unchanged thread interface and full COPYING.LIB are retained in
build/syllable-locker. The independently written RV32A atomic and XNU
identity/semaphore adapters are separate original BSD code. This is not
a Syllable Gate, Looper, Handler or AppServer port.

`thread-rv32.patch` adapts genuine libsyllable `util/thread.cpp` at the same
revision. The corresponding public Thread/exceptions/time headers stay
unchanged. The cpp has no original per-file license banner; its public
Thread header explicitly credits Henrik Isaksson (2002) and LGPL version 2.
The component COPYING.LIB and sourceLicenseBasis in sources.json document
that basis; neither the patch nor upstream source is original BSD code.
Virtual Run/_Entry survive. Native cancellation/join replaces Linux process
kill, member IDs retire after real reaping, and unsupported control/info
operations propagate errors. Prepared original/adapted sources, application
objects and separate archive remain local for exact relinking materials.
See [Thread scope](../../../docs/SYLLABLE_NATIVE_THREAD_API.md).

`messagequeue-rv32.patch` modifies the genuine LGPL-2.0-only intrusive
MessageQueue at the same pinned revision, preserving its unchanged public
header and Kurt Skauen's complete notices. It corrects tail ownership when
removing the last message, detaches popped links, propagates Locker failures,
and removes an unused obsolete kernel include. No replacement Queue or
Looper/Handler success stubs are supplied. Exact original/adapted sources,
COPYING.LIB, application objects and the separate archive remain local for
future relinking material. The independent raw-native port adapter/probe
are BSD integration code, not copies of the Syllable kernel implementation.
See [Queue and worker IPC scope](../../../docs/SYLLABLE_NATIVE_QUEUE.md).
