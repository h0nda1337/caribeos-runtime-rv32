# Next Native Thread Boundary

Audited 2026-10-13 after the genuine String/Message data-core checkpoints.
This is a dependency audit, not a claim that the missing interfaces work.
The tested kernel remains `bef8795f430f4a27cb6e76052b2c8e703690d4d089ea384f195422bcd53aac1f`.

## Verified Obstacles

The current XNU `riscv32_linux_sys_clone` deliberately rejects CLONE_VM,
CLONE_FS, CLONE_FILES, CLONE_SIGHAND or CLONE_THREAD with ENOSYS. Its tested
fork path creates a distinct child task/pmap and private heap. Existing process
thread counters or the kernel SMP scheduler do not prove multiple user threads
sharing a task. Do not implement Syllable spawn_thread by renaming fork: that
would give Looper/Handler a different address space and invalidate their pointers.

The installed GCC 15.1.0 disables native TLS and threads. In the inspected pinned
GNU `libgcc/emutls.c`, the inactive-gthread path stores the allocation in the
global emutls object's pointer. The actual process TLS tests prove fork/exec
isolation, not per-thread isolation inside one process. Starting user threads
without correcting this runtime configuration would silently share C++
thread_local state. The real threaded path requires once/mutex/thread-specific
keys and cleanup, or a suitable native-TLS toolchain/kernel/libc contract.

The pinned real `util/locker.h` needs native create/delete/lock/unlock semaphore
APIs, atomic operations and stable thread identities, not only message ports.
Its constructor does not initialize m_nOwner, and its recursive argument is
effectively ignored by the current source. These upstream issues must be patched
with LGPL notices and tests before Locker becomes a production dependency.
No success-returning semaphore/thread stub is supplied by the current port.

## Progressive Gates

1. Add versioned native XNU user-thread/semaphore interfaces without enabling
   Linux shared-thread clone flags or changing the working fork/exec path.
   Initial GUI threads must remain on CPU0; retain explicit unsupported errors.
2. Give each thread a real user entry/trampoline, stack, saved registers, TLS
   ownership, scheduler identity, join/exit state and stack/TLS reclamation.
   Share the owning task's pmap and descriptors intentionally, not by aliasing
   a process's single main-thread lifecycle fields.
3. Test native semaphore wait/wake, lost-wakeup prevention, timeout, interruption,
   deletion waking waiters, RV32A ordering and real Locker recursion/ownership.
4. Rebuild the GNU/musl threading support against the actual interfaces, then
   verify two threads have distinct errno/TLS, allocation/exception state and
   destructor cleanup. The current single-thread GNU archive cannot establish
   this gate.
5. Compile and exercise genuine Handler/Looper/Messenger with bounded Message
   input, actual dispatch and thread lifecycle. Only then enable the excluded
   Message delivery methods and advance to AppServer's multi-threaded backend.

Each gate needs independently retained UP/SMP/OpenSBI/SecureSBI evidence plus
Bash, process, shared-area and graphics regressions. Cross-hart GUI work is a
later explicit gate, not implied by the existing kernel SMP F pass. Keep X11
and Wayland outside the native Syllable dependency graph.
