# Separate native-worker allocator profile

The upstream musl 1.2.5 archive is pinned to SHA-256
`a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4`.
All 2697 original regular-file inputs are checked against that archive.
The default third_party/musl-1.2.5 and musl-rv32-sysroot are untouched.

The genuine mallocng, calloc/realloc/alignment, __lock/__unlock and private
futex algorithms are unmodified. `native-heap-rv32.patch` changes only the
RV32 syscall header to route allocator VM calls through a bounded opt-in XNU
channel. It retains MIT terms and the complete byte-identical original
[COPYRIGHT](COPYRIGHT), including contributors and third-party notices.
Neither the patch nor upstream sources receives the runtime BSD license.

The independently written lifecycle/scope integration, build/evidence tools
and probes are original BSD runtime code. The adapter enables genuine
`libc.need_locks`, protects allocator operations from forced cancellation,
and frees an unreturned allocation before committing pending cancellation.
This is not a custom allocator or a pthread/stdio/GNU-exception implementation.

Prepared exact original/adapted sources, COPYRIGHT, source records and the
separate static archive stay local under build/ for future source/relink
material. No new binary Release is created. See
[native heap scope](../../docs/SYLLABLE_NATIVE_HEAP.md).
