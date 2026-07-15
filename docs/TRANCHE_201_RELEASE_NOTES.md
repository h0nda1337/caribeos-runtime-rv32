# CaribeOS Tranche 201: Stage 2 Complete

This developer preview preserves the first validated combination of the full
RV32 process model, interactive Bash, userspace on CPU1, and stable two-hart
kernel scheduling.

## Verified

- UP boot/userland and SMP Gates A-F
- process Gates 1-15
- musl 1.2.5 and GNU Bash 5.3.5
- real task/thread/pmap process lifecycle
- signals and `rt_sigreturn`
- blocking TTY, pipes, pipelines, and selected job control
- Gate 14 with 10,000 CPU1 lifecycles
- Gate 15 in UP and SMP
- corrected `machine_stack_handoff()` reserved-stack ownership
- exact long-run resource baseline
- zero panic, unexpected trap, stale translation, or RV32A lock overlap in the
  preserved validation logs

## Kernel Identity

- Bytes: 945,004
- SHA-256: `c63fe4bfbaeaf674a4092c1c579cfe472fc433d2e89b4f55307484ed820e595e`
- Tag: `tranche-201-stage2-complete`

## Licensing

Original CaribeOS runtime code identified by the project SPDX header is
BSD-2-Clause. XNU remains under APSL 2.0 and its file-level notices, GNU Bash
remains GPL-3.0-or-later, musl retains its MIT-style terms, and OpenSBI, QEMU,
and all other external components retain their own licenses. BSD-2-Clause does
not relicense any external component.

The public-preview Release is not yet issued. Its final notes and asset list
must name the verified corresponding-source package beside every Bash/musl
binary asset before this document is treated as release-complete.

## Limitations

This is an experimental QEMU-only preview. The Linux personality, IOKit,
drivers, storage, security, and POSIX surface are incomplete. It is not a
production release and is not affiliated with Apple.
