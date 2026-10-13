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
