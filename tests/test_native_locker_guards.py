# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host validator/source guards, explicitly not guest locking evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


runner = module("locker_graphics_runner", ROOT / "scripts/test-graphics.py")


class LockerGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT AN ACTUAL BOOT\n"
            "[native-locker-gate-A] genuine os::Locker owner/recursion; RV32A old-value/CAS/exchange contract PASS\n"
            "[native-locker-gate-B] workers=16 rounds=160000 recursive acquisitions=320000 overlaps=0 cpu=0 scheduler-waits=12 PASS\n"
            "[native-locker-gate-C] immediate timeout EAGAIN cycles=64; genuine errno isolation; owner preserved; generic reaping PASS\n"
            "[native-locker] created=reaped=80 live=0 semaphores=0 all slots retired PASS\n"
            "[native-locker] gates A-C PASS; genuine Syllable Locker with native XNU threads, not Looper/AppServer or pthread lifecycle\n")

    def reject(self, old, new, message):
        with self.assertRaisesRegex(RuntimeError, message):
            runner.validate_locker_log(self.text.replace(old, new), "C")

    def test_consistent_host_fixture_checks_three_gate_logs(self):
        self.assertEqual(len(runner.validate_locker_log(self.text, "C")), 3)

    def test_missing_actual_gate_rejected(self):
        self.reject("[native-locker-gate-B]", "absent", "gate B")

    def test_zero_scheduler_waits_rejected(self):
        self.reject("scheduler-waits=12", "scheduler-waits=0", "contention")

    def test_partial_protected_increments_rejected(self):
        self.reject("rounds=160000", "rounds=159999", "contention")

    def test_partial_recursion_count_rejected(self):
        self.reject("acquisitions=320000", "acquisitions=160000", "contention")

    def test_overlapping_owners_rejected(self):
        self.reject("overlaps=0", "overlaps=1", "contention")

    def test_wrong_cpu_rejected(self):
        self.reject("cpu=0", "cpu=1", "contention")

    def test_partial_try_lock_reuse_rejected(self):
        self.reject("cycles=64", "cycles=63", "timeout/reuse")

    def test_leaked_semaphore_rejected(self):
        self.reject("semaphores=0", "semaphores=1", "resources")

    def test_wrong_reaper_count_rejected(self):
        self.reject("created=reaped=80", "created=reaped=79", "resources")

    def test_failure_after_pass_markers_rejected(self):
        self.assertTrue(runner.guest_failure("[native-locker] FAIL owner"))
        with self.assertRaisesRegex(RuntimeError, "failed Locker"):
            runner.validate_locker_log(self.text+"[native-locker] FAIL owner\n", "C")

    def test_false_appserver_claim_rejected(self):
        self.reject("not Looper/AppServer or pthread lifecycle", "AppServer complete", "incomplete")

    def test_original_locker_is_included_not_reimplemented(self):
        source = (ROOT / "userland/native_locker_probe.cpp").read_text()
        self.assertIn("#include <util/locker.h>", source)
        self.assertNotIn("class Locker", source)
        self.assertIn("mutex->Lock()==0", source)
        self.assertIn("if(!(i&31U)) yield()", source)
        self.assertIn("info.cpu==0", source)
        self.assertIn("after.waits>before.waits", source)
        self.assertLess(source.index("CARIBE_THREAD_JOIN);"), source.index("munmap(pool,16*CHUNK)"))

    def test_old_value_atomic_and_seqcst_contract(self):
        source = (ROOT / "ports/syllable/native/atheos/atomic.h").read_text()
        self.assertIn("atomic_inc_and_read(atomic_t *v) { return __atomic_fetch_add", source)
        self.assertIn("__ATOMIC_SEQ_CST", source)
        self.assertNotIn("cmpxchgl", source)
        self.assertNotIn("__asm__", source)

    def test_tcb_helper_uses_unmodified_musl_abi(self):
        source = (ROOT / "ports/syllable/native/tcb_bootstrap.c").read_text()
        self.assertIn('#include "pthread_impl.h"', source)
        self.assertIn("td=__copy_tls(reserve)", source)
        self.assertIn("TP_ADJ(td)", source)
        self.assertNotIn("struct pthread {", source)
        self.assertNotIn("__init_tp(", source)
        self.assertNotIn("pthread_create(", source)

    def test_semaphore_raw_variant_does_not_replace_default_archive(self):
        source = (ROOT / "Makefile").read_text()
        self.assertIn("-DCARIBE_SYNC_RAW_TCB", source)
        self.assertIn("build/libcaribe-syllable-locker.a:", source)
        self.assertIn("build/syllable_raw_semaphore.o", source)
        ordinary = source.split("build/libcaribe-syllable-native.a:", 1)[1].split("\n\n", 1)[0]
        self.assertNotIn("syllable_raw_semaphore", ordinary)

    def test_lgpl_patch_only_initializes_owner_and_removes_unused_include(self):
        source = (ROOT / "ports/syllable/patches/locker-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", source)
        self.assertNotIn("BSD-2-Clause", source)
        self.assertIn("+\tm_nOwner = -1;", source)
        removed = [line for line in source.splitlines() if line.startswith("-") and not line.startswith("---")]
        self.assertEqual(removed, ["-#include <sys/debug.h>"])

    def test_upstream_source_pins_are_fixed(self):
        preparer = module("locker_source_pins", ROOT / "scripts/prepare-syllable-locker.py")
        self.assertEqual(preparer.REV, "579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(preparer.FILES["system/sys/include/util/locker.h"],
                         "55743b5932e41f4b2041359229185961bb8b2691c0cc2bec29c0d549c243a74e")

    def test_modified_cached_header_rejected_before_patch_or_network(self):
        preparer = module("locker_source_rejection", ROOT / "scripts/prepare-syllable-locker.py")
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="locker-host-fixture-") as directory:
            root = Path(directory)
            source = root / "third_party/syllable/system/sys/include/util/locker.h"
            source.parent.mkdir(parents=True)
            source.write_text("HOST ONLY MODIFIED HEADER\n")
            with patch.object(preparer, "ROOT", root), patch.object(preparer, "OUT", root / "build"), \
                    patch.object(preparer, "urlopen") as network, patch.object(preparer.subprocess, "run") as apply:
                with self.assertRaisesRegex(RuntimeError, "hash mismatch"):
                    preparer.main()
                network.assert_not_called()
                apply.assert_not_called()

    def test_worker_profile_still_does_not_use_libc_allocation_or_stdio(self):
        source = (ROOT / "userland/native_locker_probe.cpp").read_text()
        workers = source.split("static void worker(uint32_t", 1)[1].split("static caribe_thread_request create", 1)[0]
        for forbidden in ("malloc(", "printf(", "puts(", "mmap(", "pthread_create("):
            self.assertNotIn(forbidden, workers)

    def test_original_adapters_not_lgpl_patch_in_bsd_allowlist(self):
        manifest = json.loads((ROOT / "docs/RUNTIME_LICENSE_SCOPE.json").read_text())
        text = json.dumps(manifest)
        self.assertIn("ports/syllable/native/atheos/atomic.h", text)
        self.assertIn("ports/syllable/native/tcb_bootstrap.c", text)
        self.assertNotIn('"ports/syllable/patches/locker-rv32.patch"', text)


class LockerEvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.collector = module("locker_evidence_collector", ROOT / "tools/collect-native-locker-evidence.py")
        fixtures = module("locker_tcb_fixture", ROOT / "tests/test_native_tcb_guards.py")
        self.parent = fixtures.TcbEvidenceGuards()
        self.parent.setUp()
        self.fixture = self.parent.fixture
        for key in ("nativeLockerProbe", "syllableLockerLibrary", "syllableLockerSources"):
            self.fixture.current[key] = "HOST-FIXTURE-"+key
        self.fixture.result["artifactSha256"] = self.fixture.current.copy()
        self.fixture.result["nativeLocker"] = {
            "gates": list("ABC"), "source": "Syllable 579e480a005321cc320e7e355e8dff398b689be8 util/locker.h",
            "workers": 16, "cpu": 0, "protectedIncrements": 160000, "recursiveAcquisitions": 320000,
            "tryLockCycles": 64, "createdReaped": 80, "appServerBuilt": False, "pthreadLifecycleImplemented": False}
        log = LockerGuards()
        log.setUp()
        self.fixture.serial += log.text
        for name, text in runner.validate_locker_log(log.text, "C").items():
            (self.fixture.source / name).write_text(text)

    def tearDown(self):
        self.parent.tearDown()

    def validate(self):
        self.fixture.validate()
        return self.collector.validate_case(self.fixture.source, self.fixture.current)

    def test_consistent_host_fixture_validates_collector_only(self):
        self.validate()

    def test_changed_locker_binary_cannot_reuse_old_pass(self):
        self.fixture.result["artifactSha256"]["nativeLockerProbe"] = "different"
        with self.assertRaisesRegex(RuntimeError, "stale nativeLockerProbe"):
            self.validate()

    def test_false_appserver_claim_cannot_be_promoted(self):
        self.fixture.result["nativeLocker"]["appServerBuilt"] = True
        with self.assertRaisesRegex(RuntimeError, "unsupported original Locker"):
            self.validate()

    def test_partial_reaper_count_cannot_be_promoted(self):
        self.fixture.result["nativeLocker"]["createdReaped"] = 79
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            self.validate()

    def test_altered_gate_log_rejected(self):
        (self.fixture.source / "gate-native-locker-B.txt").write_text("HOST ONLY altered PASS\n")
        with self.assertRaisesRegex(RuntimeError, "differs from serial"):
            self.validate()

    def test_duplicate_rebuild_artifacts_rejected(self):
        rows = [{"path": path, "sha256": "HOST-FIXTURE"} for path in sorted(self.collector.REBUILD_PATHS)]
        rows[-1] = rows[0]
        record = {"result": "PASS", "before": rows, "after": rows, "kernelRecompiled": False,
                  "forcedUserUnits": self.collector.UNITS}
        with self.assertRaisesRegex(RuntimeError, "missing or duplicate"):
            self.collector.validate_rebuild(record, {})

    def test_failed_matrix_cannot_overwrite_prior_saved_evidence(self):
        root = self.fixture.source / "runtime"
        case = root / "build/graphics-tests" / self.collector.CASES[0]
        case.mkdir(parents=True)
        (case / "result.json").write_text(json.dumps({"result": "FAIL"}))
        out = self.fixture.source / "retained"
        out.mkdir()
        sentinel = out / "last-stable.txt"
        sentinel.write_text("HOST ONLY last stable fixture\n")
        with patch.object(self.collector, "ROOT", root), patch.object(self.collector, "OUT", out), \
                patch.object(self.collector, "current_artifacts", return_value=self.fixture.current), \
                patch.object(self.collector, "verify_prepared_sources", return_value={}), \
                patch.object(self.collector, "validate_unchanged_baseline", return_value={}), \
                patch.object(self.collector, "module", return_value=SimpleNamespace(verify_sources=lambda _: {})):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                self.collector.main()
        self.assertEqual(list(out.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_text(), "HOST ONLY last stable fixture\n")


if __name__ == "__main__":
    unittest.main()
