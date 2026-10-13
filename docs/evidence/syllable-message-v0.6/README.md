# Genuine Message Data-Core Evidence

Recorded 2026-10-13. The genuine Syllable Message source runs inside XNU RV32
with real String/GNU C++/musl and atomic native-port receives. It is not a
replacement container, host simulation, or a complete AppServer library.
Looper/Handler/Variant delivery is deliberately excluded, with no fake stubs.
The legacy no-length decoder remains trusted-buffer-only; native transport
and nested Message decoding use the actual-length overload.

OpenSBI UP, strict RV32IMAC OpenSBI SMP2 and SecureSBI SMP2 each pass Message
A-D, String A-D, GNU C++ A-D, native IPC A-D, shared areas A-E, private VM,
graphics/input A-E, session restart and Bash exit zero. Two-hart tests also
require kernel SMP F; userspace remains CPU0-affine. Six actual QMP scanouts
per case show the area/graphics checks, not a complete Syllable Desktop.

Message gates verify typed arrays, nested data, real String/geometry,
alignment-safe reads, copy/self-assignment/removal and scrubbed internal
addresses/padding. Every truncation of a valid input and 10,000 malformed
structural frames end immediately before an inaccessible guest page. Old
state survives failure. Output capacity is preflighted, oversized growth is
denied and 17 nested levels are rejected. A peer independently execs and
completes 10,000 real Message Post/Read request/replies, including ten large
strings and a three-byte invalid frame. Sixteen fork/exec cycles retain the
parent's live Message. This is bounded structural validation, not a full
capability/security protocol or an audit of custom Flattenable decoders.

Forced Message and native receive adapter recompilation, probe relink and
image regeneration reproduce the hashes in rebuild.json. Kernel and GNU
C++ probe/library remain byte-identical to the preceding checkpoint.
The base initrd changes legitimately because the compatible native receive
adapter was extended; ordinary UP/IPC/areas/graphics/Bash also pass without
selecting a C++ image. The exact final `testproject.ps1` Message profile passes.
The full process-gates runner also completes all 15 targets with exit code zero;
process-regression.txt retains target/PASS markers and the full local log hash.

Kernel SHA-256:
`bef8795f430f4a27cb6e76052b2c8e703690d4d089ea384f195422bcd53aac1f`.
Message library SHA-256:
`827594554cd0483eab6c5383152b51add90b156a5913e66d5ac9b8c6eb2e0dc6`.
Message probe SHA-256:
`42e4570e37f73f39796cfc57f93d42f8acace0b1890cd593755dc62c5e6aab2d`.
Selected initrd SHA-256:
`9c2ef94729f14ba278c9c5a982213ec768df29ad56d526bb0d7c3ac8ca66a517`.

Seven host-only source guards verify pins, patch/license/header retention
and repeatable unchanged outputs. Four host-only runner guards verify profile
rejection before QEMU and stale PASS replacement, including rejection of
unexpected full Message delivery symbols. These guards do not simulate kernel
behavior. Original/adapted source hashes are retained in sources.json; full
LGPL notices and COPYING.LIB remain in the generated source tree. No binary,
ELF/archive/disk, private key or new Release asset is published here.
