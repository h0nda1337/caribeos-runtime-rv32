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

## Remaining Work

Native shared areas with fork/exec/exit lifecycle and protection enforcement
are next. The genuine Message implementation has been obtained and audited,
not compiled: it needs geometry, String/Variant, Handler/Looper/Messenger,
and C++ exception/runtime support. Its historical unchecked Unflatten input
must be hardened before accepting untrusted client messages.

AppServer itself still needs native areas, semaphores/thread APIs, FreeType,
font/bitmap/video adapters, configuration and loader support. Desktop, Dock
and FileBrowser remain unbuilt, including filesystem attribute dependencies.
The port must continue toward those actual upstream components, not replace
them with a visually similar bespoke desktop. X11/Wayland compatibility can
remain optional future sessions without becoming prerequisites for Syllable.
