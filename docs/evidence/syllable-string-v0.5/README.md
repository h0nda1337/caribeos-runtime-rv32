# Genuine Syllable String on XNU RV32

Recorded 2026-10-13. These are real QEMU executions, not host simulations.
The upstream libsyllable os::String implementation runs with actual GNU
libstdc++/musl, native XNU ports, real Sv32 process memory and Bash.
No Wayland or X11 service is involved. Message/Looper/AppServer and a complete
Desktop/Dock/FileBrowser remain unbuilt by this checkpoint.

All three cases pass: OpenSBI UP, OpenSBI SMP2 with F/D/H disabled, and
SecureSBI SMP2. Each requires String A-D, GNU C++ A-D, native IPC A-D,
shared areas A-E, private-VM, graphics/input A-E, restart and Bash exit zero.
The two-hart cases also require kernel SMP gate F; userspace remains on CPU0.
The final public runner `testproject.ps1 -Mode graphics -Smp 2 -SyllableString`
also passes after refreshing the latest kernel.

String coverage includes constructors, operators, std::string proxies,
search, erase, substring exception, valid UTF-8 byte-length counting,
10,000 empty/all-whitespace trims, unsigned ctype, copied va_list used twice,
6,000-byte formats, embedded NULs, failure preserving the old String,
16 fork/exec heap/global reinitializations and 10,000 independent-process
String/native-port request/replies, including ten >5,000-byte payloads.
The transport test uses known framed payloads; it is not an untrusted
Message parser or a claim of a full messaging/Looper implementation.

The unchanged public String header and original source/helper notices remain
LGPL-2.0-only. The versioned source patch is separately identified and dated;
the generated sources and full COPYING.LIB remain under build/syllable-string.
The source manifest records SHA-256 after LF normalization. Four host-only
tests verify pin rejection, patch rejection, unchanged output timestamps and
license/header preservation; these tests do not simulate kernel behavior.

Forced library/probe recompilation and image regeneration reproduce the
recorded hashes. The ordinary and GNU C++ initrds remain byte-identical.
Kernel SHA-256 is unchanged:
`bef8795f430f4a27cb6e76052b2c8e703690d4d089ea384f195422bcd53aac1f`.
String library SHA-256:
`874c14a861cc8d8109200e7d90d08a493a4832175de376ebebae61f30745eaa0`.
String probe SHA-256:
`cb55e191080aa25feaba8cc8421ed11792fa45e8d9afa031a1084600cf2a478a`.
Selected initrd SHA-256:
`9d12b38d85db7a47b265ab3081805901c49dbfff002414667820b3497346b887`.
No binary/ELF/archive/disk, private key or new Release asset is published here.
