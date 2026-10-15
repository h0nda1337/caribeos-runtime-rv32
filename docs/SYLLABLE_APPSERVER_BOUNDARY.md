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

## License Review

Preserve original notices per file. In particular, server.cpp's historical
banner refers to the GNU Library General Public License in its grant and
the GNU General Public License in subsequent boilerplate. That mixed text
must be retained and classified for review rather than automatically
assigning a new SPDX license or assuming every server file has identical
terms. No original upstream server, library or derived platform adaptation
may be relicensed under the runtime's original-code BSD allowlist.
