# Tranche 201 Evidence Index

Compact final evidence is stored in `docs/evidence/tranche-201`. Complete run
and serial logs remain in the timestamped local backup under `full-logs/`.

| Validation | Result | Reported duration |
|---|---|---:|
| UP | PASS | 49.3 s |
| SMP Gates A-F, six boots | PASS | 310.6 s |
| Interactive Bash | PASS | 15.5 s |
| Gate 14 at 10,000 rounds | PASS | 28.8 s |
| Gate 15 UP+SMP | PASS | 90.6 s |

The evidence summaries quote only final counters and required markers. They do
not replace full serial logs. Commit IDs, tag IDs, archive hashes, exact test
times, and exit codes are written into the external release manifest after Git
objects exist.
