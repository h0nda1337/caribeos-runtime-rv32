# Syllable AppServer Component Port

This is a real port of **DefaultDecorator** and **WindowDecorator**, not a
Syllable-lookalike Desktop or a complete AppServer. The upstream layout,
button rendering, focus rendering and hit-testing methods execute unchanged
apart from replacing `std::max` with a scalar helper. Four upstream source
files are pinned to Syllable commit
`579e480a005321cc320e7e355e8dff398b689be8` and SHA-256 checked by
[prepare-graphics-deps.py](../../scripts/prepare-graphics-deps.py).

The generated header replaces `std::string` with a bounded 159-byte title
holder. [adapter.h](adapter.h) supplies the exercised Layer, geometry, color,
frame and font interfaces over a CPU-rendered surface. Its simple frame
renderer and temporary public-domain font are adapters, not ports of the full
Syllable Layer or font subsystem. Invalidation is synchronous in this single
process; there is no emulated AppServer IPC behind the adapter.

## License and Relinking

The four upstream files retain Kurt Skauen/Syllable Team notices and
**LGPL-2.0-only**, the GNU *Library* General Public License version 2, not LGPL
2.1. The adapter is also LGPL-2.0-only. The complete text is in
[COPYING.LIB](COPYING.LIB). The separate CaribeOS test application retains its
original BSD-2-Clause license. No external code is relicensed by the runtime.
Modified upstream files carry a dated modification notice; the manifest records
both original and adapted hashes. The original CaribeOS software surface
primitives retain BSD-2-Clause and provide the library's rendering backend.
The library does not require rendering functions or buffers supplied by the
application. Its minimal C++ runtime fallbacks are weak, allowing replacement
by a full runtime later.

`make build/syllable-component.elf` saves exact upstream copies, adapted
copies, the source/hash manifest and license in `build/syllable-port/`.
It preserves separate `syllable_component.o`, `syllable_defaultdecorator.o`,
`syllable_windowdecorator.o` and `caribe_surface.o` application/library objects.
The library objects form deterministic `libcaribe-syllable-decorator.a`. Recompile
modified library copies with `GRAPHICS_FLAGS` from the runtime Makefile,
then rebuild the archive and relink with that Makefile's ELF link command.
The BSD application permits this modification and reverse engineering.
A future binary distribution must include these objects, exact corresponding
sources, adaptations, license texts, font notices and relink instructions.
This branch publishes source/build controls only; no new Release binaries.

## Next Authentic Components

AppServer still requires libsyllable's Message/Looper/Application interfaces,
semantics beyond the now verified native ports and bounded shared areas,
semaphores, thread APIs, file attributes,
dynamic libraries/decorators and FreeType. The default VESA/PCI video path
cannot run on QEMU RV32; it needs a native adapter to the existing XNU graphics
device. Full C++ ABI/exception support is also unresolved.
See [native foundations](../../docs/SYLLABLE_NATIVE.md) for the separately
tested XNU ports/shared areas and their explicit limits.

Desktop, Dock and FileBrowser have **not** been compiled or started.
Their inspected entry files carry LGPL version 2 notices, but every additional
file must still be reviewed individually. Their shared libsyllable/AppServer
dependency is currently the primary blocker. FileBrowser additionally needs
Syllable filesystem/mount/attribute semantics not present in our read-only
initrd/HFS+ environment.
