# Original Messenger And Message Delivery

This experimental opt-in profile builds the complete original Syllable
Messenger implementation and enables the original Message SendReply,
ReturnAddress and reply-handler methods alongside the original Looper.
It is not a replacement messenger, a mock AppServer or a complete desktop.
The default Message data-core library and v0.15 artifacts remain separate.
Variant methods are still excluded explicitly.

## Provenance And Adaptation

The sources are pinned to Syllable commit
579e480a005321cc320e7e355e8dff398b689be8. Messenger's original source/header
SHA-256 values are 1a84e4af331cc16674f2458a83005fb5419929b584ccaa3b01e12e9a88087b18
and 5906a53ddf672497748ed66c10870698bef585da5af0331b79827e43001c9425.
The already bounded Message adaptation supplies exact-length decoding,
wire limits and alignment-safe RV32 field access. A separate LGPL patch
enables delivery without bringing in the still-unported Variant methods.
Original copyrights, notices and COPYING.LIB are preserved.

The patch honors native send/reply deadlines, rejects a failed temporary
reply-port allocation before sending anything, preserves errno during
cleanup and restores caller-side message routing metadata. Failed replies
do not mark REPLY_SENT. Both reply overloads preserve the original reply
algorithm, with consistent IS_REPLY flags. Worker diagnostics go through
the bounded native diagnostic queue, not shared stderr. The default-target
Messenger lookup now returns the documented Looper instead of NULL.

The existing five-argument private Message::_Post symbol is preserved;
a separate private deadline overload uses the original flatten/send body.
Existing Loopers do not need an ABI-breaking class-layout change. There is
no new kernel ABI or relaxed port-receive permission in this profile.

## Guest Gates

Gate A exercises four original service Loopers and an original async reply
Looper: 10000 synchronous requests, 10000 handler-directed replies and
64 reply-to-reply acknowledgements, with exact native creation/reaping.
It also checks real target lookup/locking, reply flags and caller ownership.

Gate B fills all 32 native port slots and checks that a failed reply-port
allocation does not post a request. It checks actual destination/reply
timeouts, preserved errno, late-reply failure without loss of retry state,
and complete port/message cleanup.

Gate C starts before workers are created. It uses real fork/exec to run a
separate original Looper service, exchanges 10000 typed request/replies
across private address spaces, verifies that the remote worker cannot
receive from the client's private reply port, and requires child exit(0)
and zero remaining ports/messages. It is a dependency service, not an
AppServer implementation or claim that Application now runs.

A-C passed in a bounded UP profile on 2026-10-15 with exit(0). Full
dependency UP, SMP and SecureSBI SMP profiles also passed with the same
current binary. See [retained current-hash proof](evidence/syllable-dispatch-v0.16/manifest.json).
None of these dependency gates makes a complete AppServer/Desktop or production runtime.
Host fixtures test validators/source pinning, not guest behavior.

The initial cross-process attempt timed out at sequence 0 because the test
service added a Handler without setting it as its Looper's default target.
Messenger(port) correctly routes untargeted messages to that default, or to
the Looper itself when no default exists. The test now uses the original
SetDefaultHandler method and waits for actual Started before advertising
readiness. Both initial failed transcripts are preserved; no deadline was
relaxed to pass this correction.

One full SMP attempt stopped before Messenger at the pre-existing unchanged
Thread gate B timer/semaphore counter assertion. Its unmodified repeat
passed (640 actual timer waits and 68312 scheduler waits); the failed log
remains preserved in build/messenger-full-smp-thread-B-failure-20261015.
The intermittent counter failure is not fully isolated and remains a
stability issue, not a clean-run or production-readiness claim. No kernel,
old Thread probe, threshold or old dependency library was changed here.

## Running

```powershell
.\testproject.ps1 -Mode graphics -Smp 1 -SyllableMessenger -MessengerGate A -LooperGate A -HeapGate A -QueueGate A -SyllableThreadGate A -LockerGate A -TcbGate A -FutexGate A -ThreadGate A -Cpu rv32,f=false,d=false,h=false,zfa=false
```

MessengerGate selects A, B or C progressively. The profile implies the
Looper/heap/thread/futex dependencies and refuses disabled dependencies.
Separate initrd-messenger.img, library, probe, source record and per-gate
logs avoid replacing the default data-core or Looper probe.

Full Application/AppServer, stale-target routing, arbitrary peer death,
concurrent target destruction, Variant, production GNU threading and the
complete desktop remain outside this checkpoint and require further work.
No binary Release is produced by this source update.

The combined development matrix can be reproduced with
scripts/test-syllable-dispatch-matrix.ps1 -ReuseVerified. Reuse is opt-in
and verifies actual current hashes, complete required profile metadata,
UART gate markers and scanouts; it is not a cached PASS decision. The
script then forces GNU/native/toolkit rebuilding, runs host/PowerShell
guards and retains the full six-profile evidence. It requires the three
full original Looper profiles first and does not rerun the unchanged long
kernel process suites or silently bypass failures. Older prototyping logs
are not used as current-binary promotion evidence.
