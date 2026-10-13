# Native Syllable IPC Evidence

These QEMU results belong to kernel SHA-256
`0d3e52cda8d65a8d4b40ce6c55688f476da5bed09c87517451bab62a95935010`.
They verify the native message-port foundation, not a complete AppServer or
Desktop. Neither Wayland nor X11 runs or provides the tested transport.

| Case | Native IPC | Graphics/Input | Private VM | Bash |
| --- | --- | --- | --- | --- |
| OpenSBI, UP | A-D PASS, 10,000 exchanges | A-E PASS | 32 fork-exec + 256 reuse | PASS |
| OpenSBI, SMP2, base RV32IMAC without F/D/H | A-D PASS, 10,000 exchanges | A-E PASS | 32 + 256 | PASS |
| SecureSBI, SMP2 | A-D PASS, 10,000 exchanges | A-E PASS | 32 + 256 | PASS |

Both SMP cases also require the existing kernel SMP Gate F. GUI/IPC test
processes are CPU0-bound; these results do not establish cross-hart userspace
IPC or a multi-threaded AppServer. Captures are actual QMP scanouts of the
already ported Syllable decorators after IPC completed, not a new desktop.

Each case records the exact nine artifact hashes, native/graphics gates and
five screenshot hashes. Kernel native_ipc/linux_syscall/linux_exec units and
runtime probe/adapter objects were force-recompiled and relinked. Kernel,
probe, deterministic archive and initrd hashes matched before and after.
This is incremental reproducibility evidence, not a clean-host toolchain build.

Port limits: 32 ports, 64 messages, 32 messages per port and 8192-byte payloads.
Queued-data zeroing, owner enforcement, public discovery, generation IDs,
timeouts, FIFO, no-loss EFAULT/undersized receive, resource saturation, 256
recycle cycles, independent exec peer and exec/exit cleanup are tested.
The source manifest distinguishes unchanged LGPL headers from audited,
currently uncompiled Syllable Message code. No ELF or private keys are included.
