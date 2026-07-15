# Testing CaribeOS

`testproject.ps1` is the release runner. It rebuilds XNU before every selected
suite and rejects missing commands, missing semantic markers, nonzero make
status, panic patterns, and gate-specific counter failures.

## Tranche 201 Validation Set

```powershell
.\testproject.ps1 -Mode up -Seconds 45 -KeepHistory
.\testproject.ps1 -Mode gates -Seconds 50 -KeepHistory
.\testproject.ps1 -Mode interactive -Seconds 120 -KeepHistory
.\testproject.ps1 -Mode process-stability -Seconds 300 -KeepHistory
.\testproject.ps1 -Mode process-stress -Seconds 300 -StressRounds 10000 -KeepHistory
```

`gates` runs six boots:

- Gate A: hart 1 entry with independent stack, trap state, and `cpu_data_t`
- Gate B: bidirectional SBI IPI/SSIP ping-pong
- Gate C: XNU idle thread and per-hart timer
- Gate D: 10,000 bound kernel-thread synchronizations
- Gate E: shared pmap RFENCE with `stale=0`
- Gate F: both processors online with RV32A locks and `overlap=0`

`process-stability` runs Gate 15 once in UP and once in SMP. Gate 15 exercises
1,000 fork-only cycles, 1,000 fork/exec cycles, 1,000 pipes, 1,000 signals,
100 pipelines, child batches, and 1,000 canonical TTY lines. The runner checks
zero zombies and exact resource accounting.

`process-stress` runs Gate 14 with 10,000 CPU1 process lifecycles and verifies
fork, U-mode entry, exec, `getcpu`, exit, reap, pmap/backing release, page and
zone baselines, plus the SMP gates.

## Pass Criteria

- required `PASS` and `QEMU smoke test OK` markers present
- no semantic `FAIL`, panic, or unexpected trap
- `stale=0`, `overlap=0`, gate errors zero
- `zombies=0` when reported
- before/after resource counters equal
- no orphaned QEMU, make, linker, or compiler process
- final ELF hash recorded

The broad `all` mode duplicates several component suites and is not needed
when the nonredundant set above has already passed.
