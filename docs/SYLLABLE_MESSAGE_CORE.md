# Genuine Message Data Core

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -SyllableMessage
```

This optional profile compiles genuine Syllable libsyllable `message.cpp`
against the already verified real String/GNU C++/musl stack. It is not a
replacement associative container or a mock messaging server. Its auditable
LGPL patch retains the original notices and has a dated modification notice.
The selected image is `build/initrd-message.img`; ordinary builds do not need
the GNU library or these optional C++ components.

`CARIBE_SYLLABLE_MESSAGE_CORE` excludes Looper/Handler reply delivery,
Messenger/ReturnAddress and Variant methods at compile time. These symbols
are deliberately **not implemented**, even as success-returning stubs; the
runner checks that they are absent. The resulting archive is not the complete
libsyllable library. AppServer, Desktop, Dock and FileBrowser remain unbuilt.
There is no dependency on a Linux kernel, Wayland or X11. The XNU Linux syscall
compatibility layer continues supplying musl/Bash process services.

## Bounded Serialization

The new `Unflatten(buffer, actualSize)` overload validates the complete extent
before reading array data or allocating. It enforces the existing RV32 wire
layout, a transport-sized 8,192-byte limit, nonnegative lengths, bounded counts,
fixed scalar widths, complete variable chunks, string terminators, bool
representations and nested Messages with a maximum depth of 16. It requires
the declared length to equal the actual received length. Input failure or
allocation failure preserves the destination's previous contents.

Flatten preflights capacity before writing, uses alignment-safe header copies,
and scrubs heap pointers and padding from array headers. Chunk metadata and
typed/geometry lookups use alignment-safe RV32 reads. Copy assignment now
handles self-assignment, allocation failure and old array reclamation. Removing
the last value of a name correctly decrements the flattened size. AddData
limits name widths and arithmetic/allocation growth for this bounded profile.

**Legacy limitation:** the one-argument Unflatten and Message(void*) constructor
have no actual-length parameter. They remain only for trusted, complete buffers;
reading a self-declared length does not prove the memory extent. Do not use them
for network/client/port input. `FindMessage` and the native `_ReadPort` route
through the bounded overload. Custom Flattenable decoders, Variant and remaining
untrusted-object policies still require separate audits; this structural parser
is not a complete security/capability protocol.

The original Syllable `get_msg_x` continues returning status zero on success.
The original CaribeOS `caribe_get_message` extension additionally returns the
actual byte count from the same atomic XNU receive operation. No separate
size-query/read race is introduced. New `PostPort`/`ReadPort` entry wrappers
expose the genuine internal `_Post`/`_ReadPort` paths for the bounded data-core
integration; they do not emulate Looper or Handler dispatch.

## Gates

- A: genuine typed arrays, nested Message/String, geometry, lookup, copying,
  removal, alignment-safe access and no serialized internal heap pointers.
- B: every truncation of a valid frame and 10,000 malformed structural frames
  end immediately before a real inaccessible guest page; old state survives.
  Short output buffers remain unchanged; oversize growth and nesting are denied.
- C: independent exec'd peer, 10,000 real Message Post/Read request/replies,
  ten large strings, exact receive lengths and rejection of a three-byte frame.
- D: 16 fork/exec cycles preserve a parent's live Message heap.

All runs additionally execute String, GNU C++, native IPC/shared-area,
private-VM and actual graphics/input/restart/Bash gates. Two-hart runs require
kernel SMP gate F while all these user processes remain on CPU0.
The profile does not claim native GUI threads or native ELF TLS: the installed
GCC is still single-threaded with GNU emulated TLS.

Original/adapted hashes and all selected upstream notices are retained under
`build/syllable-message/`. Full COPYING.LIB, application objects, String/Message
archives and the GNU archive allow relinking; future binary packages must ship
the exact sources, notices, modifications and relink instructions. No new
binary Release is created and Tranche 201's tag/assets remain untouched.

The next actual dependency barrier is native GUI threading and Locker,
not another visual imitation. See [thread boundary audit](SYLLABLE_THREAD_BOUNDARY.md)
for the verified kernel/GNU/upstream obstacles and progressive gates.
