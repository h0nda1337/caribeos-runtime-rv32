# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only adversarial log guards, not proof of guest scheduling."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("futex_runner", ROOT / "scripts/test-graphics.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
spec = importlib.util.spec_from_file_location("futex_collector", ROOT / "tools/collect-native-futex-evidence.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class FutexGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT AN ACTUAL BOOT\n"
            "[native-futex-gate-A] ABI timeouts PASS\n"
            "[native-futex-gate-B] rounds=10000 actual waiters woken=10000 acknowledgements=10000 zero lost events PASS\n"
            "[native-futex-gate-C] sixteen simultaneous waiters; zero/one/fifteen bounded wakes and separate address key PASS\n"
            "[native-futex-gate-D] blocked cancellations=64 owner-exit cycles=8; same-VA distinct-pmap isolation; zero waiter leaks PASS\n"
            "[native-futex] created=reaped=89 live=0 all slots retired PASS\n"
            "[native-futex] gates A-D PASS; private futex scheduler waits, not pthread or threaded libc\n")

    def test_consistent_host_fixture_checks_four_logs(self):
        self.assertEqual(len(runner.validate_futex_log(self.text, "D")), 4)

    def test_missing_gate_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "gate C"):
            runner.validate_futex_log(self.text.replace("[native-futex-gate-C]", "missing"), "D")

    def test_partial_counter_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "10000"):
            runner.validate_futex_log(self.text.replace("woken=10000", "woken=9999"), "D")

    def test_owner_cleanup_required(self):
        with self.assertRaisesRegex(RuntimeError, "cleanup"):
            runner.validate_futex_log(self.text.replace("owner-exit cycles=8", "owner-exit cycles=7"), "D")

    def test_waiter_limit_required(self):
        with self.assertRaisesRegex(RuntimeError, "simultaneous"):
            runner.validate_futex_log(self.text.replace("zero/one/fifteen", "all"), "D")

    def test_worker_failure_never_retained_as_pass(self):
        with self.assertRaisesRegex(RuntimeError, "failed"):
            runner.validate_futex_log(self.text+"[native-futex] FAIL lost event\n", "D")
        self.assertTrue(runner.guest_failure("[native-thread] FAIL invalid TID"))

    def test_false_pthread_completion_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            runner.validate_futex_log(self.text.replace("not pthread or threaded libc", "pthread complete"), "D")

    def test_disabled_profile_requires_real_rejection_marker(self):
        off = ("[native-futex] disabled profile worker futex=ENOTSUP; conservative raw-thread syscall boundary PASS\n"
               "[native-futex] created=reaped=1 live=0 all slots retired PASS\n")
        self.assertEqual(list(runner.validate_futex_log(off, "D", True)), ["gate-native-futex-off.txt"])
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            runner.validate_futex_log(off.replace("ENOTSUP", "0"), "D", True)

    def test_final_reaper_resources_required(self):
        with self.assertRaisesRegex(RuntimeError, "reaper resources"):
            runner.validate_futex_log(self.text.replace("created=reaped=89", "created=reaped=88"), "D")

    def test_native_queue_locks_exclude_same_hart_kernel_preemption(self):
        candidates = (ROOT.parent.parent / "xnu-2050.48.11", ROOT.parent / "xnu")
        kernel = next((path for path in candidates if (path / "osfmk/riscv32/native_futex.c").is_file()), None)
        self.assertIsNotNone(kernel, "paired XNU source is required for the lock contract guard")
        for filename, lock, prefix in (("native_futex.c", "futex_lock", "futex"),
                                      ("native_thread.c", "native_thread_lock", "nt"),
                                      ("native_sync.c", "sync_lock", "sync")):
            source = (kernel / "osfmk/riscv32" / filename).read_text()
            acquire = source.split(f"static void {prefix}_lock_queue(void)", 1)[1].split("}", 1)[0]
            release = source.split(f"static void {prefix}_unlock_queue(void)", 1)[1].split("}", 1)[0]
            self.assertLess(acquire.index("disable_preemption();"), acquire.index(f"simple_lock(&{lock});"))
            self.assertLess(release.index(f"simple_unlock(&{lock});"), release.index("enable_preemption();"))
            self.assertEqual(source.count(f"simple_lock(&{lock})"), 1)
            self.assertEqual(source.count(f"simple_unlock(&{lock})"), 1)
            initializer = source.split(f"static void {prefix}_init(void)", 1)[1].split("static uint32_t", 1)[0] if prefix != "futex" else source.split("static void futex_init(void)", 1)[1].split("static int futex_finish", 1)[0]
            self.assertLess(initializer.index("disable_preemption();"), initializer.index("__sync_bool_compare_and_swap"))
            self.assertLess(initializer.index("initialized = 2U"), initializer.index("enable_preemption();"))

    def test_runner_refuses_hfs_rebuild_with_existing_qemu(self):
        source = (ROOT / "scripts/qemu-rv32-graphics.ps1").read_text()
        self.assertLess(source.index("Refusing HFS rebuild"), source.index('$makeArguments ='))
        self.assertNotIn("Stop-Process", source)
        self.assertLess(source.index("$diskLock.WaitOne(0)"), source.index("$makeArguments ="))
        self.assertIn("$diskLock.ReleaseMutex()", source)
        self.assertIn("$diskLock.Dispose()", source)

    def test_proto_queries_honor_cpu_binding_under_shared_runqueue_lock(self):
        candidates = (ROOT.parent.parent / "xnu-2050.48.11", ROOT.parent / "xnu")
        kernel = next((path for path in candidates if (path / "osfmk/kern/sched_proto.c").is_file()), None)
        self.assertIsNotNone(kernel, "paired XNU source required")
        source = (kernel / "osfmk/kern/sched_proto.c").read_text()
        helper = source.split("sched_proto_eligible_work(processor_t processor)", 1)[1].split("#endif", 1)[0]
        self.assertLess(helper.index("simple_lock(&global_runq_lock)"), helper.index("thread->bound_processor != processor"))
        self.assertLess(helper.index("thread->bound_processor != processor"), helper.index("simple_unlock(&global_runq_lock)"))
        for function in ("sched_proto_processor_queue_empty", "sched_proto_processor_queue_has_priority",
                         "sched_proto_processor_csw_check", "sched_proto_processor_runq_count"):
            body = source.rsplit(function + "(", 1)[1].split("#endif", 1)[0]
            self.assertIn("#if defined(__RISCV32__)", body)
            self.assertIn("sched_proto_eligible_work(processor)", body)
        self.assertIn("work.count > 0 && (gte ? work.highq >= priority : work.highq > priority)", source)

    def test_raw_user_preemption_preserves_trap_frame_for_normal_ast(self):
        candidates = (ROOT.parent.parent / "xnu-2050.48.11", ROOT.parent / "xnu")
        kernel = next(path for path in candidates if (path / "osfmk/riscv32/native_thread.c").is_file())
        source = (kernel / "osfmk/riscv32/native_thread.c").read_text()
        boundary = source.split("void riscv32_native_thread_user_boundary(void)", 1)[1].split("void riscv32_native_thread_fault", 1)[0]
        self.assertIn("(reasons & AST_PREEMPT)", boundary)
        self.assertIn("wait_queue_assert_possible(current_thread())", boundary)
        self.assertLess(boundary.index("ast_off(AST_PREEMPTION)"), boundary.index("thread_block_reason(THREAD_CONTINUE_NULL, NULL, reasons)"))
        self.assertNotIn("ast_taken(AST_PREEMPTION", boundary)

    def test_gate14_records_use_one_atomic_uart_write(self):
        candidates = (ROOT.parent.parent / "xnu-2050.48.11", ROOT.parent / "xnu")
        kernel = next(path for path in candidates if (path / "osfmk/riscv32/linux_exec.c").is_file())
        for filename in ("linux_exec.c", "linux_syscall.c"):
            source = (kernel / "osfmk/riscv32" / filename).read_text()
            self.assertNotIn('riscv32_early_puts("[process-gate-14] exec pid=', source)
            self.assertNotIn('riscv32_early_puts("[process-gate-14] child pid=', source)
            self.assertNotIn('riscv32_early_puts("[process-gate-14] getcpu pid=', source)
            self.assertNotIn('riscv32_early_puts("[process-gate-14] Bash pid=', source)
            self.assertIn('riscv32_early_puts(record);', source)


class FutexEvidenceGuards(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("futex_base_fixture", ROOT / "tests/test_native_thread_guards.py")
        fixtures = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixtures)
        self.fixture = fixtures.NativeThreadGuards()
        self.fixture.setUp()
        self.fixture.current["nativeFutexProbe"] = "HOST-FIXTURE-futex"
        self.fixture.result["artifactSha256"] = self.fixture.current.copy()
        self.fixture.result["nativeFutex"] = {"gates": list("ABCD"), "enabled": True,
            "privateOnly": True, "pthreadImplemented": False, "createdReaped": 89,
            "actualWakes": 10000, "blockedCancellations": 64, "ownerExitCycles": 8}
        log_fixture = FutexGuards()
        log_fixture.setUp()
        self.fixture.serial += log_fixture.text
        for name, text in runner.validate_futex_log(self.fixture.serial, "D").items():
            (self.fixture.source / name).write_text(text)

    def tearDown(self):
        self.fixture.tearDown()

    def validate(self):
        self.fixture.validate()
        return collector.validate_case(self.fixture.source, self.fixture.current)

    def test_consistent_host_fixture_validates_collector_only(self):
        self.validate()

    def test_stale_futex_binary_cannot_reuse_prior_pass(self):
        self.fixture.result["artifactSha256"]["nativeFutexProbe"] = "old"
        with self.assertRaisesRegex(RuntimeError, "stale nativeFutexProbe"):
            self.validate()

    def test_partial_futex_gates_are_rejected(self):
        self.fixture.result["nativeFutex"]["gates"] = list("ABC")
        with self.assertRaisesRegex(RuntimeError, "incomplete private-futex"):
            self.validate()

    def test_shared_or_pthread_claims_are_rejected(self):
        self.fixture.result["nativeFutex"]["privateOnly"] = False
        with self.assertRaisesRegex(RuntimeError, "unsupported pthread"):
            self.validate()

    def test_final_reaper_count_is_required(self):
        self.fixture.result["nativeFutex"]["createdReaped"] = 88
        with self.assertRaisesRegex(RuntimeError, "reaper count"):
            self.validate()

    def test_altered_gate_file_does_not_match_guest_serial(self):
        (self.fixture.source / "gate-native-futex-C.txt").write_text("HOST ONLY altered PASS\n")
        with self.assertRaisesRegex(RuntimeError, "differs from actual serial"):
            self.validate()

    def test_incomplete_rebuild_cannot_be_promoted(self):
        with self.assertRaisesRegex(RuntimeError, "incomplete forced"):
            collector.validate_rebuild({"result": "PASS", "before": [1], "after": [1],
                                        "forcedKernelUnits": ["native_futex"]}, self.fixture.current)

    def test_duplicate_rebuild_artifacts_are_rejected(self):
        rows = [{"path": "xnu", "sha256": "HOST-ONLY-fixture"} for _ in range(13)]
        units = ["native_thread", "native_sync", "linux_syscall", "linux_process", "pmap",
                 "riscv32_thread", "syscall", "trap", "native_futex", "sched_proto", "linux_exec"]
        with self.assertRaisesRegex(RuntimeError, "duplicate forced artifact"):
            collector.validate_rebuild({"result": "PASS", "before": rows, "after": rows,
                                        "forcedKernelUnits": units}, self.fixture.current)

    def test_failed_matrix_keeps_prior_stable_evidence(self):
        root = self.fixture.source / "runtime"
        case = root / "build/graphics-tests" / collector.CASES[0]
        case.mkdir(parents=True)
        (case / "result.json").write_text(json.dumps({"result": "FAIL"}))
        out = self.fixture.source / "retained"
        out.mkdir()
        sentinel = out / "last-stable.txt"
        sentinel.write_text("HOST ONLY stable fixture\n")
        with patch.object(collector, "ROOT", root), patch.object(collector, "OUT", out), \
             patch.object(collector, "current_artifacts", return_value=self.fixture.current):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                collector.main()
        self.assertEqual(list(out.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_text(), "HOST ONLY stable fixture\n")


if __name__ == "__main__":
    unittest.main()
