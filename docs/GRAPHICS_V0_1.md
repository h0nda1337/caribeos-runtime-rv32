# Native Graphics v0.1

Development branch: `develop/graphics-v0.1`, based on the security development
branch. The preserved Tranche 201 tag and stable branches are unchanged.

## Executable Result

The chain remains OpenSBI or SecureSBI -> CaribeBootX -> HFS+ -> XNU RV32.
CBX does not paint the display. An independent RV32-musl process, launched by
Bash through `/bin/caribe-session`, runs the original Syllable AppServer
decorator against a software surface, submits pixels to XNU, and receives
real virtio input events. See [Syllable port details](../ports/syllable/README.md).
The port is linked as a separate deterministic library, including a native
software surface backend rather than application-provided rendering globals.

Implemented in XNU: virtio-MMIO split queues, virtio-gpu 2D resource creation,
DMA backing attachment, scanout, transfer/flush, keyboard/tablet receive
queues, ordered native events, bounded transactional rectangle copies,
device ioctls, frame/event counters and CPU0 confinement.
The current mode is fixed 800x600 XRGB8888; no mode switching, acceleration,
DRM/KMS, shared render buffers or full window manager is claimed.

The native ABI is [caribe_graphics.h](../include/uapi/caribe_graphics.h),
accessed through `/dev/caribe-graphics`. GET_MODE, BLIT, PRESENT,
GET_EVENT and GET_STATS are versioned fixed-width RV32 structures, with
compile-time size assertions and a runner check against the kernel header. BLIT
validates ABI, dimensions, stride, overflow and user mappings, copies the
complete rectangle to staging, then changes backing pixels. PRESENT is a
synchronous host transfer/flush, not a vblank/refresh guarantee.
The backend is independent of Syllable, X11 and Wayland.

## Run the Latest Build

From the runtime in PowerShell:

```powershell
.\testproject.ps1 -Mode graphics -Smp 2
.\testproject.ps1 -Mode graphics-live -Smp 2
```

The first command rebuilds current XNU/runtime, executes gates and saves
screenshots. The second opens the real QEMU window and starts the configured
component. Keyboard Tab changes focus, mouse dragging uses Syllable's real
HitTest result, Escape exits the component. Close the QEMU window to stop the
live runner. This is a component test session, **not Syllable Desktop**.

Python with Pillow is required; the wrapper selects the bundled host Python
when available, otherwise a compatible Python from PATH. Override using
`scripts/qemu-rv32-graphics.ps1 -PythonPath ...`.
The optional firmware is selected without modifying SecureSBI:

```powershell
.\scripts\qemu-rv32-graphics.ps1 -Smp 2 -Bios ..\..\securesbi\build\platform\generic\firmware\fw_dynamic.bin
```

QEMU uses `-M virt -m 256 -bios default -kernel build/caribe_rv32.elf`
plus `virtio-blk-device`, `virtio-gpu-device`, `virtio-keyboard-device`
and `virtio-tablet-device`. Disk format/CBX legacy block transport are
unchanged. Tests use snapshot disks, loopback-only structured QMP, and stop
only their own QEMU process. No kernel Linux, RV64 or hypervisor is added.

The additional CPU test explicitly disables hardware floating point and H:

```powershell
.\scripts\qemu-rv32-graphics.ps1 -Smp 2 -Cpu 'rv32,f=false,d=false,h=false,zfa=false'
```

QEMU 11 enables Zfa by default, so it must also be disabled with F. The boot
reports base ISA `rv32imac`; other default Z/S extensions remain enabled.
This is a no-F/D/H execution test, not a claim that QEMU exposes only IMACSU.
Its evidence directory ends in `-imacsu`.

## Gates and Evidence

[scripts/test-graphics.py](../scripts/test-graphics.py) records separate
gate logs, serial logs, PNG screenshots, hashes and JSON results below
`build/graphics-tests/<firmware>-smp<N>/`.
Results identify the kernel, CBX, initrd, decorator library, application,
session manager and private-VM probe by SHA-256.
Committed [compact evidence and screenshots](evidence/graphics-v0.1/README.md)
record the verified matrix without distributing generated kernel binaries.

- A: real XNU GPU setup and two input devices.
- B: invalid dimensions, overflow, kernel pointers, `/proc` FD-kind isolation
  and unknown ioctl rejection.
- C: separate ELF process and nonblank 800x600 QEMU scanout.
- D: actual title-bar pixels change on keyboard focus; mouse drag moves the
  Syllable border to the expected coordinates; eleven keyboard actions arrive.
- E: contiguous event sequence, no drops, balanced frame submission,
  clean exit, return to Bash, session restart, a subsequent shell command,
  PID1 reaping. Counters are measured relative to each session's baseline.
- VM: 32 fork/exec isolation cycles and 256 mmap zeroing/recycling cycles.

Graphics and its application remain CPU0-only; the existing kernel SMP Gate F
continues to run on the second hart. Native graphics is an experimental,
trusted single-session interface, not hostile-client isolation.

## VM Regression Fixed

The previously global physical brk/mmap buffers were mistakenly reused by
independent process pmaps. A child reading the session config could overwrite
Bash's allocator/job state. Managed tasks now allocate private pages from the
existing ownership-checked backing pool. Fork copies them, exec releases old
backing, munmap fences before recycling, and exit accounts/releases ownership.
A lock serializes scratch preparation across CPUs. Legacy bootstrap mapping
is retained where no managed process exists.

Gate 15 now disables shell history and primes resource-parser buffers before
sampling: newly counted private shell heap growth would otherwise be mistaken
for a workload leak. All exact live-resource and allocation/free equality
assertions remain, and the full 2,300+ process stress matrix is still required.
Gate 14's exact backing allocation/free expectation includes the worker's
one private mmap page after exec, in addition to its fork copies. This page
was formerly an uncounted shared static buffer. Live resource and zone
baselines are unchanged and remain strictly checked on every cycle.
The broad regression also exposed a Gate 5 scheduling assumption: global
pipe counts at child exit can include the parent's still-open endpoints.
The gate now verifies that the child exits without pipe endpoints and that
the complete fixture returns to zero pipes with exactly one allocation,
one release and four bytes written/read. Resource assertions remain exact.
Repeated CPU1 stress additionally exposed a startup timer bug: each secondary
idle poll moved the first SBI timer into the future, occasionally preventing
Gate C from observing any IRQ. The bootstrap deadline now lives in the CPU's
XNU etimer state. Idle may advance a late scheduler deadline for the first
interrupt, but never postpones an earlier or pending deadline. Gate C waits up to one
second of actual monotonic time and still requires an idle thread and a real
timer IRQ. The interactive/graphics runners abort on explicit SMP gate FAIL.
The final regression caught another existing SMP issue: UART writes from
both harts interleaved inside a required Gate 14 entry record. Early console
writes now use an RV32A lock with SIE save/restore and MMIO barriers;
cross-hart entry/clone/wait records are assembled before emission. User console
writes are serialized in existing bounded chunks. Multipart legacy records
are not universally converted into atomic lines. No runner regex was relaxed
to tolerate a corrupted entry record.

## IPC and Protocol Audit

| Facility | Actual status / blocker |
|---|---|
| Processes/threads/Sv32/SMP/signals/pipes | Existing native XNU mechanisms retained |
| MAP_PRIVATE and brk | Per-process backing isolation corrected and tested |
| MAP_SHARED, memfd/shared areas | Not implemented; needs refcounted VM objects, fork/exec/munmap lifecycle |
| AF_UNIX/socketpair | Not implemented; required for real Wayland transport |
| sendmsg/recvmsg/SCM_RIGHTS | Not implemented; needs retained OFDs, atomic install/rollback and secure ownership |
| poll/pselect/ppoll | Existing tested TTY/pipe paths; new graphics uses nonblocking native event ioctl |
| epoll | Descriptor allocation exists, ctl/pwait are provisional; not a real event dispatcher |
| timerfd | Existing provisional interface, not a verified compositor timer source |
| Timers | Existing monotonic/nanosleep paths used by this process |
| PTY | UART controlling TTY exists; no pseudoterminal master/slave pair |
| AppServer IPC | Not implemented; AtheOS ports/areas require real native adapters |

No Wayland interfaces or X11 server are claimed operational in this milestone.
[Wayland's official protocol](https://wayland.freedesktop.org/docs/book/Protocol.html)
requires an AF_UNIX stream and out-of-band FDs, including shared-memory buffer
transport; byte messages over pipes alone would not fulfill that contract.
The next implementation should port libwayland rather than hand-roll a
lookalike protocol. It needs libffi/scanner, actual epoll, SCM_RIGHTS and shared
VM first, then versioned wl_display/registry/compositor/surface/shm and
xdg-shell, followed by seats/outputs.

[Xwayland's architecture](https://wayland.pages.freedesktop.org/wayland.freedesktop.org/docs/book/Xwayland.html)
also requires a compositor/X window-manager integration and protocol
dependencies. X11 transport, pixman/libXfont/XKB and related X server
dependencies are not ported. Future software Xwayland or X.Org backends
should reuse this same XNU scanout/input ABI, not introduce Linux drivers.

## Session Configuration

[session.conf](../userland/stage1/etc/caribe/session.conf) is packaged in the
read-only initrd and currently selects `syllable`, mapped explicitly to the
AppServer component test. `caribe-session --list` advertises unavailable
Wayland/X11 entries as blocked. Selecting either fails honestly rather than
substituting the component. Command-line selection overrides this image
setting. RAM is not persistent storage; changing the packaged config requires
rebuilding the initrd. An installed/writable system and full desktops remain
future work.
