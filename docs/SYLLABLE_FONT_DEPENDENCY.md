# Genuine Font Dependency v0.8

Verified 2026-10-13. This removes a real external dependency required by
Syllable's `appserver/server/sfont.h` and `sfont.cpp`: FreeType. It does not
compile or replace Syllable's Font, SFont, FontFamily, AppServer or Desktop.
Their original sources remain the intended next consumers of this dependency.

## Authentic Inputs

- FreeType 2.15.0 from its [official mirror](https://github.com/freetype/freetype/tree/37515cf56ba3349656049edbed89ffc6f6466f2d),
  release tag `VER-2-15-0`, commit `37515cf56ba3349656049edbed89ffc6f6466f2d`,
  annotated tag object `631ee12ce7693c9ba9ea33f0235da99218045420`.
- The preparer checks every one of 775 original Git blobs, their object hashes,
  working-copy bytes, commit and tag pins; only checkout CRLF normalization is
  allowed. Modified/untracked source files are rejected. No GPG verification
  is claimed. The unused dlg submodule is recorded, not fetched or compiled.
- Unmodified Bitstream Vera 1.10 from the [GNOME publisher](https://download.gnome.org/sources/ttf-bitstream-vera/1.10/),
  archive SHA-256 `3a84126ce11ef404d1453438e35450b9e0838220d262059e56cd8496ac6f5d15`.
  Regular, bold and monospace fonts and their complete COPYRIGHT.TXT enter the
  optional initrd. No proprietary host fonts are used.
- FreeType's FTL option and per-file BDF/PCF, internal zlib and embedded
  HarfBuzz notices are preserved. [The attribution](../ports/freetype/NOTICE.md)
  also enters the image. No dependency is BSD-relicensed or published as a
  new binary Release. Original independent controls/probe are BSD-2-Clause.

## Cross Build

```powershell
.\scripts\build-freetype-rv32.ps1 -Jobs 2
.\testproject.ps1 -Mode graphics -Smp 2 -FreeType -NativeSync -SyllableMessage
```

The static archive is installed at
`build/freetype-rv32-sysroot/usr/lib/libfreetype.a`. CMake uses the F: RV32
compiler with ILP32, `rv32imac_zicsr_zifencei`, soft float and exclusively
musl headers. Compile probes are static-only. External zlib, bzip2, PNG,
HarfBuzz, Brotli, HVF and dynamic HarfBuzz are disabled; this is not complex
text shaping, accelerated rendering or support for every optional font format.
Internal gzip code still retains its upstream license. Existing Syllable
decorator text is unchanged; the new capture is the font dependency test,
not a newly completed GUI Font implementation.

The default initrd and earlier development profiles remain available. The
explicit `-FreeType` profile selects `build/initrd-fonts.img`, containing the
existing C++/String/Message/semaphore probes plus fonts and font notices.
`-FontGate A`, `B`, `C`, or `D` stops the new tests progressively (default D).
The OpenSBI/SecureSBI -> CBX ELF -> HFS+ -> XNU chain is unchanged.

## Real Guest Gates

| Gate | Verified behavior |
| --- | --- |
| A | Genuine runtime version 2.15.0, TrueType face, 268 glyphs, 2048 UPEM, Unicode cmap and nonzero metrics |
| B | Gray coverage, solid pixels, mono rasterization, emboldening, negative AV kerning, shear transform and 10,000 glyph renders at varying sizes |
| C | 256 truncated fonts ending immediately before an inaccessible guard page; 1,024 invalid signatures; 32 allocation-fault thresholds with actual rejected allocations; balanced custom allocator and library shutdown |
| D | Independent exec renders all three faces into shared Sv32 pages; parent independently renders a reference and compares every byte; GPU presents the frame; QMP observes the matching 800x600 scanout; all shared objects/views/pages released |

Gate C is targeted parser/allocator coverage, not a claim of comprehensive
font fuzzing or security certification. Later fault thresholds retry face
creation until they really reach a failing allocation. Optional allocation
recovery is allowed only with balanced cleanup. Engine memory callbacks track
every allocation/free/reallocation, without patching upstream FreeType.

Gate D uses two native areas totaling 938 pages, below the existing 1024-page
pool. It does not grow kernel limits. A 1.92 MiB malloc was correctly rejected
by the current 1 MiB private-mmap limit; the reference now uses the intended
native area API. Both buffers are independently rendered and byte-compared
before GPU upload. QMP's RGB-word FNV-32 matches guest `94e1ac1d`; this is
pixel-integrity evidence, not a cryptographic attestation.

All four gates pass in three full dependency matrices with no F/D/H:
OpenSBI UP, OpenSBI SMP2, SecureSBI SMP2. Each also executes genuine GNU C++,
String, Message, native IPC, shared areas, counting semaphores/clock waits,
private-VM isolation, graphics/input/restart and Bash exit(0). SMP cases
retain kernel gate F; no additional userspace is scheduled on hart 1.

## Reproduction

```powershell
.\scripts\test-font-rebuild.ps1
```

The forced build recompiles 43 FreeType C units, recompiles the probe and
repacks the optional initrd. Ten artifacts remain byte-identical, including
the ordinary initrd, native/String/Message/GNU libraries and CBX. The XNU
kernel remains `8af38adb36da0b1a5d600037362fdb8363bbbf10c323de692f25a6559b9ecdbd`;
the prior v0.7 process 15/15 regression is preserved, not rerun or relabeled.
The evidence collector rejects stale artifacts, missing gates/scanouts or
changed-kernel reuse before touching retained results.

48 host-only unit tests pass, including source preservation, archive path
containment, invalid ELF/hard-float/dynamic-loader rejection, scanout byte
order and stale-evidence protection. Synthetic collector fixtures do not
constitute guest results. A Windows PowerShell native-stderr issue was also
fixed: diagnostics remain logged, native exit codes still decide success,
and a real warning/exit-7 test verifies the helper without launching QEMU.

See [retained matrix and captures](evidence/syllable-fonts-v0.8/README.md).
Full serial logs and actual object archives remain under ignored `build/`.

## Next Mandatory Boundary

Original SFont includes `util/locker.h`; AppServer/Looper also needs real
shared-task user threads and correct per-thread GNU/musl TLS. Kernel SMP and
these independent-process font tests do not satisfy that contract.
[The native thread audit](SYLLABLE_THREAD_BOUNDARY.md) remains applicable.
No fork-as-thread alias, successful thread stub, invented Desktop, X11 or
Wayland dependency is introduced by this milestone.
