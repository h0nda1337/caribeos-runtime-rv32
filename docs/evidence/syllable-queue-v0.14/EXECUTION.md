# Verified MessageQueue and native worker IPC v0.14

Actual QEMU RV32IMACSU matrix ran 2026-10-13, with the public-runner recheck
on 2026-10-14. This is the original
Syllable MessageQueue and real XNU worker port integration, not Looper,
AppServer or a desktop imitation.

- Progressive UP A/B and full UP C, separately retained.
- Three full OpenSBI SMP runs and SecureSBI SMP with signing-denial proof.
- Unchanged original Thread-profile UP/SMP; default-off thread/futex profiles.
- Existing graphics/input, IPC/shared areas, GNU C++/String/Message,
  semaphores, FreeType, raw thread/futex/TCB/Locker/Thread gates preserved.
- Queue A: 100 tail/sole-node removal/reuse cycles and native IPC input guards.
- Queue B: 16 genuine Threads and 160,000 protected typed Message/Queue cycles,
  independent TCB/errno/native TLS, CPU0, zero overlapping owners.
- Queue C: 10,000 worker/controller wire exchanges, maximum 8192-byte payload,
  64 actual finite timeouts of at least 2 ms, 16 simultaneous deleted-port
  waiters and generation reuse without consuming replacement messages,
  64 blocked reader/writer cancellations, balanced waits/wakeups.
- Exact C totals: 161 create/exit/reap, 64 cancellations, zero live/fault
  deltas and restored ports/messages/semaphores plus actual pool release.
- Actual native_ipc/syscall kernel compilation/relink and original Queue,
  raw/default port adapter and image rebuild: 31 byte-identical artifacts.
- Every prior v0.13 userland artifact and stable kernel snapshot unchanged.
- Fresh 15/15 process runner targets for this exact new kernel hash.
- 206 host unit tests, three actual PowerShell guard scripts and 34 tracked
  PowerShell files parsed. Host fixtures are never substituted for guest proof.
- The public testproject graphics/SMP/SyllableQueue command also passed on
  2026-10-14 with the same final kernel hash and actual Bash exit/reaping.

Final artifact SHA-256:

```text
kernel: 3ce43707797289b77771df757d1e09a2da48e55b4f09f35187467115d67393e2
queue probe: d33ef04287340a94bad1bd08a58767e2566554a9bec8d8621f5e29b9ecea6f8f
queue library: 5c0989be57c8923bf4833b4eac16b6e25febf68e3d9017b3dd30c30427e57f29
queue initrd: 03105302f194b8ea34b9fac0beed1b55a80992668e702f497f9b6b8cfdcec880
queue sources: 928fd8206a146e14f2503283b3151a1b6cd05004aa45a42ed2e20630306986cf
```

## Regressions caught

The first source patch did not account for the upstream cpp's leading empty
line. Hash verification retained the exact original input; git apply rejected
the patch, so no substitute Queue was compiled. Correcting the patch context
preserved upstream bytes and notices.

The first probe linked no native PT_TLS because its TLS fixture was unused
and garbage collected. The runner rejected the ELF before QEMU launch.
Actual per-worker initialized/zero TLS checks and identity writes now retain
that original fixture; the unchanged strict ELF verifier and all guest gates
pass. No check was relaxed to accept a TLS-less worker test.

Native port waits previously changed the shared Linux process state and the
IPC simple lock allowed local preemption. They now use independent worker
wait/cancellation state and preemption-safe lock/initialization wrappers.
Ordinary Linux worker syscalls remain restricted; the same native port backend
still enforces owner, generation, payload and copy transaction checks.

## Scope and evidence

The [manifest](manifest.json), separate gate logs, scanouts, source pins,
rebuild record and fresh process receipt identify the actual proof. Full
serial/build logs and snapshots remain local under build/. Short retained
directory slugs preserve complete case identifiers without Windows path issues.

MessageQueue/header/patch retain LGPL-2.0-only and original notices. Independent
integration is original BSD runtime code; XNU retains APSL. No new binary
Release, stable/main update, protected-tag change, paid service or visibility
change is part of this checkpoint.

Workers do not allocate/decode Message objects, use stdio, implement pthread
lifecycle or threaded GNU exceptions. Genuine Handler/Looper, worker-safe
libc/GNU runtime, AppServer, Desktop, Dock and FileBrowser remain required.
The native graphics/font frames demonstrate retained dependencies, not a
complete desktop. The full desktop goal stays active without X11/Wayland.
