# Remaining Authentic AppServer Boundary

The source inventory below was inspected at Syllable revision
579e480a005321cc320e7e355e8dff398b689be8, not inferred from the running
decorator component. It is a remaining-work boundary, not a boot claim.

The original server Makefile names 27 ordinary object units:
ddriver, ddline, ddmemory, event, vesadrv, server, input, config, keyboard,
keymap, defaultkeymap, sapplication, swindow, layer, toplayer, render,
bitmap, crdtrans, sfont, fontnode, wndborder, desktop, winselect, sprite,
clipboard, windowdecorator and defaultdecorator. Screenshot support is
optional and adds a further unit plus PNG/zlib dependencies.
Compiling two decorator units does not compile this server.

The real Application constructor uses Messenger with DR_CREATE_APP,
process/event-port/name fields, then reads the returned application command
port and color configuration. Its destructor and window/font/input/config
methods use further original server protocols. The independent Looper echo
service in the Messenger gates intentionally does not register as an
AppServer, return fabricated DR_CREATE_APP success or replace Application.

## Required Integration

1. Build the real public Application/Window/View/Font and supporting utility
   interfaces from pinned upstream inputs; preserve their public ABI and
   implement their required backends rather than successful placeholder stubs.
2. Build the actual SrvApplication/SrvWindow and server protocol dispatch.
   The native Messenger/Message/Looper development gates now provide real
   request/reply transport, not the rest of this server protocol.
3. Port the actual Layer/render/clipping/bitmap/sprite/window-management
   implementation. The temporary Layer adapter used by the decorator demo
   cannot stand in for this compositor or the complete original GUI library.
4. Supply a real platform DisplayDriver/input backend over the existing
   /dev/caribe-graphics ABI, native shared areas and virtio input. The
   original VESA/PC paths cannot be treated as RV32 platform drivers.
5. Integrate real FontServer/SFont and the authentic FreeType dependency.
   Existing font-rendering gates alone do not implement the server font API.
6. Handle original image/plugin/resource/config/filesystem contracts against
   actual supported OS facilities, with explicit unsupported results where
   work is unfinished. Native filesystem node monitoring is still absent.
7. Run the original Desktop, Dock and FileBrowser against that real server,
   with actual input, multiple windows, IPC and process shutdown. Screenshots
   of the existing decorator are not proof of these applications.

General worker stdio, broader GNU threading, exception_ptr/shared-state
contracts, stale-target/lifecycle races and the intermittent old Thread B
counter assertion still need attention. Neither the native transport gates
nor a green source compilation closes these contracts.

## Next Client Integration Contracts

The original `libsyllable/gui/control.cpp` stores a Variant and its Invoked
hook calls `Message::AddVariant("value", ...)`. The separate original typed
value profile addresses that dependency, not Control/View implementation.
Original `libsyllable/util/invoker.cpp` supplies the actual GUI notification
path through Messenger, including its `source` pointer and virtual Invoked
hook. Its default constructors depend on `Application::GetInstance()`; do
not provide a substitute Application singleton to make a test link.

The genuine `util/application.h` directly includes Window, Font, Locale,
Catalog and keyboard-event interfaces as well as Looper. Its implementation
constructs a real Locale and keeps real Catalog references. Those contracts
must be ported or reported unfinished, not replaced with empty success.

At this revision the original Application constructor leaves its server
application command port uninitialized before a possibly failed DR_CREATE_APP
exchange, then asserts it is nonnegative. Native bring-up must initialize
port IDs to invalid values, validate the actual reply and clean up/propagate
failure. An arbitrary nonnegative value or a fake handshake cannot prove a
working Application/AppServer connection. Its normal shutdown must terminate
windows, unregister shortcuts, send M_QUIT and release owned reply/catalog
resources through their real interfaces.

An isolated complete-client compilation audit is versioned as
`scripts/audit-syllable-client-compile.py`. It requires the ignored upstream
audit clone at the exact revision above, verified cached original headers,
and the already prepared genuine native/C++ dependencies. For a new audit
clone, use `git clone --filter=blob:none --no-checkout` with the official
`https://github.com/SyllableOS/Syllable.git` remote into
`build/syllable-upstream-audit`, then select the exact revision with
`git -C build/syllable-upstream-audit update-ref --no-deref HEAD <revision>`
without materializing the entire source tree. The
tool verifies Git blob identities before using sources or cached headers.
It must not include the decorator's temporary Layer/GUI adapter directory.

`--retain-evidence` retains compiler logs and unresolved symbols even when
the audit is INCOMPLETE, with exit code 1 and `runtimeVerified: false`.
Compiling a complete original translation unit is not a link, a successful
Application handshake or GUI runtime verification. Original Application and
Font still encounter obsolete historical platform include paths; following
those through to real native APIs remains required.

The optional `--native-platform` mode now applies explicit Application/Font
include patches in a separate output tree and compiles all six complete
client units. A real native relocatable link and the complete 27-unit server
audit are documented in [the client/server frontier](SYLLABLE_CLIENT_SERVER_FRONTIER.md).
That server audit remains INCOMPLETE; neither tool constitutes a running GUI.

## License Review

Preserve original notices per file. In particular, server.cpp's historical
banner refers to the GNU Library General Public License in its grant and
the GNU General Public License in subsequent boilerplate. That mixed text
must be retained and classified for review rather than automatically
assigning a new SPDX license or assuming every server file has identical
terms. No original upstream server, library or derived platform adaptation
may be relicensed under the runtime's original-code BSD allowlist.
