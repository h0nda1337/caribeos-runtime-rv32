# Authentic Client And Server Frontier

Verified 2026-10-25, using the pinned original Syllable revision
`579e480a005321cc320e7e355e8dff398b689be8` and the real RV32 soft-float
toolchain. This is compilation and relocatable-link evidence, not a running
Application, AppServer or desktop. No new image or kernel is selected.

## Complete Client Units

The original complete Application, Invoker, Window, View, Font and Control
translation units compile. Two LGPL patches replace Application/Font's
obsolete kernel umbrella with specific public port/time/atomic includes.
No public class, singleton, method body, server reply or GUI is replaced.
Original notices are preserved. Existing bounded native diagnostics and
standard string/limits includes are explicit compiler adaptations.

The six objects form a deterministic 503324-byte static client archive.
A real RV32 `ld -r` link against the existing Variant, Messenger, Looper,
Queue, Thread, String and native IPC libraries also succeeds. It retains
the original Application singleton, Font initialization, Control methods,
Message typed values, Looper and actual port definitions. This is an ELF
relocatable object, not an executable; no undefined symbols are suppressed.

The eight object/archive/partial-link artifacts were actually rebuilt and
were byte-identical. Corresponding commands and hashes are retained in
`evidence/syllable-client-platform-20261025/`. The unresolved list identifies
real next dependencies: ShortcutKey, Keymap, Locale/catalogs, Bitmap, Desktop,
Menu and ScrollBar, plus normal GNU/libc/context providers still required
at final executable link. No substitute Locale or Application was supplied.
Existing native get/set_app_server_port already route to real kernel IPC;
their presence is not proof that an authentic AppServer has registered.

```powershell
python scripts/audit-syllable-client-compile.py --native-platform --retain-evidence
```

The default audit without `--native-platform` remains the separate original
compilation investigation. It does not overwrite this native output tree.

## Complete Server Inventory

The server auditor derives all 27 ordinary units from the original Makefile,
including VESA. It verifies Git blob identities, copies original private
headers, uses actual FreeType/public/native dependencies and compiles full
translation units. It never uses the decorator demo's temporary Layer adapter.

24 of 27 units compile into RV32 soft-float objects, including the real Layer,
TopLayer, Render, SrvApplication, SrvWindow, SrvBitmap, FontServer, FontNode,
Sprite, desktop/window management and original DefaultDecorator. These are
not replacement classes. The remaining failures are retained explicitly:

- ddriver: architecture-dependent MMX/copy-row code, initially diagnosed at
  the assembler-label alias `g_nCopyRow`.
- vesadrv: x86 real-mode BIOS structures and `realint`; RV32 must use a real
  native DisplayDriver rather than pretend to support VESA BIOS.
- server: O_NOTRAVERSE semantics and an old signed `case -1` in an unsigned
  command switch. No open flag is defined as zero and no narrowing check
  is disabled to hide either issue.

The scoped, independently written server umbrella only includes actual API
headers. It supplies no kernel implementation or successful unsupported API
stub. EOK is the original zero success constant, verified against the pinned
Syllable errno header; it is not a fabricated operation result. Server
diagnostics retain the original int-returning declaration, not an incompatible
void-function alias. Unsupported APIs remain unresolved for real integration.

```powershell
python scripts/audit-syllable-server-compile.py --retain-evidence
```

The server audit intentionally returns 1 / INCOMPLETE while any unit fails.
Its retained evidence is partial compiler proof, not an overall PASS. None
of these objects has been promoted to the boot image or claimed as runtime
verification. The exact inventory, original hashes, logs and unresolved
symbols are in `evidence/syllable-server-frontier-20261025/`.

## Next Required Integration

Port the actual generic display engine off MMX and provide a native
DisplayDriver over the existing graphics/shared-area ABI. Integrate the
genuine server entry, input, font/resource/config paths and real client
utilities. Before runtime promotion, fix Application's failed-handshake
initialization/cleanup and validate the real DR_CREATE_APP/AR_CREATE_FONT
exchanges. Then exercise original Window/View/Control against the authentic
server before claiming Desktop, Dock or FileBrowser progress at runtime.

The previous v0.17 guest gates and default image remain unchanged. The new
host suite passes 303 tests; it is not a new guest boot. Broad GNU threading,
shared stdio, node monitoring and the older intermittent Thread B counter
assertion still require work. This milestone publishes source/patches and
compiler evidence only, not new binary assets. The historical mixed server
license notices are preserved and classified for review, not relicensed BSD.
