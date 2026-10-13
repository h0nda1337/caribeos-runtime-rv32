# Native Syllable Desktop Port

The active goal is the authentic Syllable AppServer, GUI libraries, Desktop,
Dock and FileBrowser running on XNU RV32IMACSU. **Neither Wayland nor X11 is
a dependency.** The current decorated-window component is not the complete
desktop and does not satisfy that goal.

## Native Ports Foundation

`/dev/caribe-ipc` routes a fixed 128-byte versioned ioctl into XNU. It provides
32 process-owned ports, 64 pooled messages, up to 32 queued messages per port,
and 8192-byte payloads. Names are discoverable only after publication; knowing
a port ID permits sending, while receiving/deleting/publishing requires its
owner. Generation-bearing IDs prevent access through stale recycled IDs.
These are experimental local IPC IDs, not cryptographically unguessable
capabilities or a production multi-user security boundary.

RV32A simple locks serialize queues and resource ownership. Blocked operations
use XNU event waits, sequence counters to close lost-wakeup races, monotonic
deadlines and signal interruption. There is no polling message transport.
Insufficient receive buffers and failed copyout preserve the queued message.
Failed create copyout never publishes an orphaned port. Resource exhaustion
has explicit errors. Queued data is zeroed when reclaimed.

Ports are image-owned: successful exec and exit revoke them, including the
AppServer registry. Failed exec leaves ownership intact. Fork inherits the
IPC device descriptor through the existing OFD machinery, not parent-owned
receive permissions. Public Syllable message-port signatures come from the
unchanged pinned upstream header. The original CaribeOS binding implements
create/delete, send/receive, finite/infinite waits, peek, info, visibility,
name lookup, owner/public port enumeration and AppServer registration.
`get_msg_size` waits for the next message without consuming it. Undersized
receives intentionally preserve the message and report EMSGSIZE, unlike the
historical AtheOS truncation/consume/E2BIG behavior.

For STATS, `ports/messages/sends/receives` are resource/traffic counters;
`limit/flags/code` report scheduler blocks/wakeups/timeouts. SEND/DELETE/PUBLIC
do not return an updated request. Receive returns code and actual byte count.
Individual native waits are capped at 60 seconds; longer finite Syllable
timeouts retain a monotonic total duration. Infinite Syllable waits accept
the upstream INT64_MAX constant and renew deadlines without spinning.
The adapter is currently for single-threaded
clients; concurrent C library initialization needs a native thread integration
before full multi-threaded AppServer use.

## Verified Gates

Run from PowerShell with the installed toolchain:

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeIpc
```

This rebuilds current XNU/runtime/HFS+ and executes native IPC before the
existing visual graphics/input/restart/Bash gates. Logs and screenshots are
separate from v0.1 under `build/graphics-tests/*-native-ipc/`.

- A: ABI, FIFO, queue bounds, EFAULT/no-loss, metadata, visibility, stale IDs,
  and a real timed scheduler wait.
- B: all 32 ports and 64 messages, exhaustion, 256 reclaim/reuse cycles and
  exact zero live-resource baseline.
- C: an independently exec'd peer, owner permission checks, 10,000 bidirectional
  payload-verified exchanges including 8192-byte payloads and actual XNU waits.
- D: deliberately leaked queued child ports reclaimed on exit; successful exec
  removes old ports/messages; the AppServer registry is cleared on deletion.

Both participants in these graphics/session tests remain on CPU0. SMP kernel
gates A-F run with two harts, but this is not yet a cross-hart IPC stress claim.

## Native Shared Areas

The unchanged pinned Syllable `atheos/areas.h` now binds create/clone/delete/info
to XNU objects with real shared physical backing, not copied private mmap pages.
Each process has independently protected Sv32 views. Fork preserves the area
ID, address, protection and backing; ordinary private pages still use eager
private cloning. Successful exec and exit remove only that process's views.
Failed exec leaves them intact. Last-view deletion invalidates translations
through pmap before zeroing and recycling pages. Failed create copyout removes
all new translations and backing. Fork resource exhaustion rolls back instead
of silently omitting views.

This is a bounded, wired prototype: 32 objects, 64 views, 1024 backing pages
(4 MiB total), at most 512 pages (2 MiB) per object. The fixed 128-byte versioned
AREA ioctl uses the same native device. A reserved `0x68000000..0x70000000` user
VA band prevents Linux mmap/munmap/mprotect/mremap from bypassing area ownership
or changing a view's protection. ANY and EXACT address policies are supported.
READ and READ|WRITE are supported; clone cannot escalate source protection.
Physical remap is denied. EXEC, kernel mappings, contiguous allocation, other
address policies and unbounded/demand-paged areas are explicitly unsupported.
NO/LAZY lock requests currently receive stronger FULL wired backing, reported
honestly by get_area_info. Known IDs permit cloning; these are experimental
local sharing handles, not a production multi-user capability boundary.

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeAreas
```

This includes native IPC gates, the following shared-area gates, existing
private VM isolation, authentic Syllable decorator input/restart and Bash:

- A: shared writes, read-only copyout enforcement, no protection escalation,
  exact-address collision, reserved-VA guards, stale IDs, zeroing and full
  EFAULT create rollback.
- B: all 32 objects/64 views/1024 pages, explicit exhaustion, failed fork
  rollback, 256 zeroed reuse cycles and no live resources.
- C: inherited same-ID/same-VA shared writes, failed exec preservation and
  successful exec revocation without deleting the parent's live view.
- D: independently exec'd peer, 10,000 shared-memory exchanges synchronized
  with native ports and acquire/release barriers, creator deletion, live-view
  retention and leaked child-view exit cleanup.
- E: a forked child renders 800x600 pixels into shared backing; the parent
  presents it through the actual native GPU, then reclaims the last view.
  The host checks five deterministic scanout pixels, not just a UART marker.

Logs/captures use separate `build/graphics-tests/*-native-areas/` directories.
These are two CPU0 processes with SMP kernel work online in the two-hart cases,
not yet multi-threaded/cross-hart GUI processes. The shared framebuffer test
does not claim to be the complete AppServer.

## Remaining Work

The genuine Message data core now compiles and executes with a bounded
LGPL source patch and real String/geometry/GNU C++ integration. It is not the
complete Message/Looper subsystem: Variant, Handler/Looper/Messenger delivery
remains explicitly excluded. The historical one-argument Unflatten API is
trusted-buffer-only; actual port and nested Message input now uses the
actual-length overload. See [Message core](SYLLABLE_MESSAGE_CORE.md).

AppServer itself still needs semaphores/thread APIs, FreeType,
font/bitmap/video adapters, configuration and loader support. Desktop, Dock
and FileBrowser remain unbuilt, including filesystem attribute dependencies.
The port must continue toward those actual upstream components, not replace
them with a visually similar bespoke desktop. X11/Wayland compatibility can
remain optional future sessions without becoming prerequisites for Syllable.
The historical Bitmap client requests AREA_FULL_ACCESS for a data buffer;
porting it must explicitly remove EXEC from that request, not silently grant
executable shared memory or pretend the current adapter supports all flags.

The optional `-NativeCxx` graphics profile now verifies actual GNU containers,
streams, RTTI, 10,000 exceptions/unwind destructors, global exit destructors
and 16 independent fork/exec cycles before the native IPC/area/visual gates.
This removes the basic single-thread C++ runtime obstacle, not native threads:
the installed GCC uses emulated TLS and a single-thread model. Appropriate
native Syllable thread/Looper/semaphore integration is still required.

The optional `-SyllableString` graphics profile additionally compiles and
executes genuine libsyllable `os::String`, not a compatibility reimplementation.
It keeps the original public header and licenses, with an auditable LGPL
source patch for musl/RV32 portability and historical trim/formatting bugs.
Four gates cover the actual API, 10,000 empty/all-space trim operations,
large/copied-va_list/error/embedded-NUL formats, 16 fork/exec cycles and
10,000 independent-process String/native-port exchanges. It includes all
GNU C++/IPC/area/visual gates. This does not start Message or AppServer.
See [String source changes](../ports/syllable/patches/README.md).
The additional `-SyllableMessage` profile runs the genuine Message data core
with 10,000 malformed guard-page inputs, 10,000 independent exec'd Post/Read
exchanges and 16 process lifecycle tests. This does not start AppServer.
