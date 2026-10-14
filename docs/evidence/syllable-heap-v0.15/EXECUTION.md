# Verified genuine musl worker heap v0.15

Actual QEMU RV32IMACSU matrix and public-runner recheck ran 2026-10-14.
This is genuine musl mallocng plus original Syllable worker Message transport,
not an allocator replacement, pthread implementation or running AppServer.

- Separate UP A/B/full C; three full OpenSBI SMP runs; SecureSBI SMP.
- Original Queue UP/SMP preserved; default-off thread/futex/heap profiles.
- A: genuine worker allocation and VM checks, protected stack/TCB pages,
  invalid stack alignment rejection and one-byte destructive VM denial.
- B: 16 workers, 160,000 calloc/realloc/aligned/free cycles and 10,000
  original worker Message/Queue construction, flattening and bounded decoding.
- C: 10,000 original worker ReadPort typed messages; 64 actual musl-lock
  futex cancellations and 64 unreturned results freed before cancellation.
- Eight critical allocator-fault processes aborted by SIGSEGV and eight
  owner-exit processes discarded their heap after native worker teardown.
- Exact full totals: 163 created/exited/reaped, 72 cancellations, eight
  expected faults, 16 abandoned scopes, zero active scopes and owner waiters.
- Real native_thread/linux_syscall/syscall compilation, link, six genuine
  musl allocator/lock/VM units, scope/probe/image rebuild: 38 artifacts identical.
- All v0.14 userland and its stable kernel snapshot unchanged.
- Fifteen fresh actual process-runner targets passed on the final kernel hash.
- 247 host tests, three PowerShell runner guard scripts, 37 tracked PowerShell
  files parsed. Host fixtures do not replace guest or visual proof.
- Public testproject graphics/SMP/SyllableHeap command passed with the same
  kernel hash, native graphics/font/input/restart checks and Bash exit(0).

Final artifact SHA-256:

```text
kernel (956528 bytes): 2f6df12958747994e625dd648bd24b013fae2e400025bf59f5eedcd2321e9304
heap probe: da45b1b92c09d572a7c21d6df3c8d2a220297d3c43912bd1797bf6708eb061d3
heap musl libc.a: 9ae999d7f0b1534287aaac7c7cf0fc1805a7f96db767a45d78e2f4d5e52ac19d
heap initrd: e7884d306b9e077cab0b88b3fee0780811749df3dcd44ef3e9dd59c6f0cdc9d2
heap sources: 0362e912fe7f3c12fcedb196de08aa38ea450d5c535dd1aa34409168ba2eb418
```

## Findings

An unused malloc/free test pair was initially optimized away, so the strict
actual-waiter gate stopped. A checked allocation and observable volatile
write retain that real call; no futex or cancellation threshold was reduced.

QMP screendump failed on a long Windows path after successful guest gates.
Owned short temporary PPM paths now preserve full case identities, final
PNG captures and the existing nonblank/pixel/input checks.

Fresh Gate 14 CPU1 work/exit/reap succeeded but concurrent multipart UART
records corrupted the required waitid marker. Exec-argument/waitid-option
records now use the existing IRQ-safe console's single-write path. The failed
logs remain local in build/heap-gate14-failed-20261014/. Gate 14 and the entire
matrix/rebuild/process suite then passed with the corrected kernel.

An earlier old Thread B timer/semaphore assertion failed once. Its unchanged
repeat and final UP/SMP profiles passed. The initial cause remains unisolated;
50-us registration timing is an open diagnostic item, not a claimed fix.

## Boundaries

All 2697 original musl inputs and complete COPYRIGHT are checked; mallocng,
locks and public headers are untouched. Only the separate RV32 VM-routing
patch adapts upstream code, retaining MIT. Original Syllable archives remain
LGPL-2.0-only; runtime integration is BSD and XNU remains APSL.

Cancellation grace expiry is checked at user boundaries, not independently
enforced for a worker indefinitely blocked inside an allocator scope. General
application-resource cleanup, pthread lifecycle, worker stdio, GNU thread
exceptions, PROT_NONE guards and larger VM capacity remain unfinished.

Full logs and binary snapshots stay local under build/. The manifest, separate
gate logs, source pins, rebuild record and captures retain the actual evidence.
No new binary Release, protected-tag/main update, paid service or visibility
change is part of this checkpoint. The authentic desktop goal stays active.
