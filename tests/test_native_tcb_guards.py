# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only TCB ABI/evidence guards, never proof of guest TLS scheduling."""
import importlib.util
import hashlib
import io
from pathlib import Path
import struct
import tempfile
import tarfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tcb_graphics_runner", ROOT / "scripts/test-graphics.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class TcbGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT AN ACTUAL BOOT\n"
            "[native-tcb-gate-A] genuine musl __copy_tls TCB/DTV=16; native PT_TLS initialized/zero image; main pthread_self/errno PASS\n"
            "[native-tcb-gate-B] workers=16 checks=160000; private pthread_self/errno/native TLS; futex resumes=16 cpu=0 PASS\n"
            "[native-tcb-gate-C] reuse cycles=64 cancellation requests=16; fresh TLS/errno; main unchanged; zero waiter leaks PASS\n"
            "[native-tcb] created=reaped=96 live=0 all slots retired PASS\n"
            "[native-tcb] gates A-C PASS; musl TCB/native ELF TLS only, not pthread lifecycle or threaded libc\n")

    def test_consistent_host_fixture_checks_three_gate_logs(self):
        self.assertEqual(len(runner.validate_tcb_log(self.text, "C")), 3)

    def test_missing_gate_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "gate B"):
            runner.validate_tcb_log(self.text.replace("[native-tcb-gate-B]", "absent"), "C")

    def test_partial_counter_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "worker stress"):
            runner.validate_tcb_log(self.text.replace("checks=160000", "checks=159999"), "C")

    def test_wrong_cpu_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "worker stress"):
            runner.validate_tcb_log(self.text.replace("cpu=0", "cpu=1"), "C")

    def test_live_tcb_resources_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "reaper"):
            runner.validate_tcb_log(self.text.replace("live=0", "live=1"), "C")

    def test_partial_reuse_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "reuse/cancellation"):
            runner.validate_tcb_log(self.text.replace("reuse cycles=64", "reuse cycles=63"), "C")

    def test_failure_rejected_even_after_pass_markers(self):
        self.assertTrue(runner.guest_failure("[native-tcb] FAIL private errno"))
        with self.assertRaisesRegex(RuntimeError, "failed TCB"):
            runner.validate_tcb_log(self.text+"[native-tcb] FAIL private errno\n", "C")

    def test_false_pthread_claim_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            runner.validate_tcb_log(self.text.replace("not pthread lifecycle or threaded libc", "pthread complete"), "C")

    def elf(self, kind=7, memsz=20, alignment=16, image=0x13579bdf):
        data = bytearray(100)
        data[:7] = b"\x7fELF\x01\x01\x01"
        struct.pack_into("<HH", data, 16, 2, 243)
        struct.pack_into("<I", data, 28, 52)
        struct.pack_into("<HH", data, 42, 32, 1)
        struct.pack_into("<8I", data, 52, kind, 96, 0x10060, 0x10060, 4, memsz, 4, alignment)
        struct.pack_into("<I", data, 96, image)
        return data

    def verify(self, data):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="tcb-elf-guard-") as directory:
            path = Path(directory) / "host-fixture.elf"
            path.write_bytes(data)
            runner.verify_tcb_elf(path)

    def test_real_tls_shape_required_not_only_elf_header(self):
        self.verify(self.elf())
        with self.assertRaisesRegex(RuntimeError, "PT_TLS"):
            self.verify(self.elf(kind=1))

    def test_zero_initialized_tls_space_required(self):
        with self.assertRaisesRegex(RuntimeError, "TLS image"):
            self.verify(self.elf(memsz=4))

    def test_exact_native_image_and_alignment_required(self):
        for data in (self.elf(alignment=4), self.elf(image=0)):
            with self.assertRaisesRegex(RuntimeError, "TLS image"):
                self.verify(data)

    def test_unmodified_musl_abi_used_not_fabricated_pthread_structure(self):
        source = (ROOT / "userland/native_tcb_probe.c").read_text()
        self.assertIn('#include "pthread_impl.h"', source)
        self.assertIn("tcbs[slot]=__copy_tls(mem)", source)
        self.assertIn("TP_ADJ(tcbs[slot])", source)
        self.assertIn("mine==&self->errno_val", source)
        self.assertIn("close(-1)==-1 && errno==95", source)
        self.assertNotIn("struct pthread {", source)
        self.assertNotIn("__init_tp(", source)
        self.assertNotIn("pthread_create(", source)
        self.assertLess(source.index("CARIBE_THREAD_JOIN,cancel?"), source.index('"pool release after reaper"'))


class TcbEvidenceGuards(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("tcb_evidence_collector", ROOT / "tools/collect-native-tcb-evidence.py")
        self.collector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.collector)
        spec = importlib.util.spec_from_file_location("tcb_futex_fixture", ROOT / "tests/test_native_futex_guards.py")
        fixtures = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixtures)
        self.parent = fixtures.FutexEvidenceGuards()
        self.parent.setUp()
        self.fixture = self.parent.fixture
        for key in ("nativeTcbProbe", "muslLibrary"):
            self.fixture.current[key] = "HOST-FIXTURE-"+key
        self.fixture.result["artifactSha256"] = self.fixture.current.copy()
        self.fixture.result["nativeTcb"] = {"gates": list("ABC"), "muslVersion": "1.2.5", "nativeElfTls": True,
            "pthreadLifecycleImplemented": False, "threadedLibcImplemented": False,
            "cpu": 0, "workers": 16, "stressChecks": 160000, "reuseCycles": 64,
            "cancellationRequests": 16, "createdReaped": 96}
        log = TcbGuards()
        log.setUp()
        self.fixture.serial += log.text
        for name, text in runner.validate_tcb_log(log.text, "C").items():
            (self.fixture.source / name).write_text(text)

    def tearDown(self):
        self.parent.tearDown()

    def validate(self):
        self.fixture.validate()
        return self.collector.validate_case(self.fixture.source, self.fixture.current)

    def test_consistent_host_fixture_checks_evidence_only(self):
        self.validate()

    def test_changed_libc_cannot_reuse_old_tcb_pass(self):
        self.fixture.result["artifactSha256"]["muslLibrary"] = "different"
        with self.assertRaisesRegex(RuntimeError, "stale muslLibrary"):
            self.validate()

    def test_false_pthread_lifecycle_rejected(self):
        self.fixture.result["nativeTcb"]["pthreadLifecycleImplemented"] = True
        with self.assertRaisesRegex(RuntimeError, "unsupported musl TCB"):
            self.validate()

    def test_partial_reaped_counter_rejected(self):
        self.fixture.result["nativeTcb"]["createdReaped"] = 95
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            self.validate()

    def test_modified_gate_log_rejected(self):
        (self.fixture.source / "gate-native-tcb-B.txt").write_text("forged PASS\n")
        with self.assertRaisesRegex(RuntimeError, "differs from serial"):
            self.validate()

    def test_duplicate_rebuild_artifact_rejected(self):
        rows = [{"path": path, "sha256": "HOST-FIXTURE"} for path in sorted(self.collector.REBUILD_PATHS)]
        rows[-1] = rows[0]
        record = {"result": "PASS", "before": rows, "after": rows, "kernelRecompiled": False,
                  "forcedUserUnits": ["native_tcb_probe.c", "native_tcb_tls.S"]}
        with self.assertRaisesRegex(RuntimeError, "missing or duplicate"):
            self.collector.validate_rebuild(record, {})

    def test_matrix_does_not_change_prior_evidence_or_kernel(self):
        source = (ROOT / "scripts/test-native-tcb-matrix.ps1").read_text()
        self.assertIn("-SkipKernelBuild", source)
        self.assertIn("test-native-tcb-rebuild.ps1", source)
        self.assertNotIn("test-native-thread-process-regression.ps1", source)
        collector = (ROOT / "tools/collect-native-tcb-evidence.py").read_text()
        self.assertIn('"reusedNotRerun": True', collector)
        self.assertLess(collector.index("baseline = validate_unchanged_kernel_baseline"), collector.index("target.mkdir"))


class MuslSourceGuards(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("musl_original_source_guard", ROOT / "tools/verify-musl-tcb-source.py")
        self.verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.verifier)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="musl-source-host-fixture-")
        self.root = Path(self.temp.name)
        self.archive = self.root / "third_party/musl-1.2.5.tar.gz"
        self.archive.parent.mkdir()
        with tarfile.open(self.archive, "w:gz") as archive:
            for path in self.verifier.INPUTS:
                data = ("HOST ONLY FIXTURE "+path+"\n").encode()
                member = tarfile.TarInfo("musl-1.2.5/"+path)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
                local = self.root / "third_party/musl-1.2.5" / path
                local.parent.mkdir(parents=True, exist_ok=True)
                local.write_bytes(data)
                if path.startswith("include/") and Path(path).name in self.verifier.INSTALLED:
                    installed = self.root / "build/musl-rv32-sysroot/usr/include" / Path(path).name
                    installed.parent.mkdir(parents=True, exist_ok=True)
                    installed.write_bytes(data)
        self.pin = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def tearDown(self):
        self.temp.cleanup()

    def verify(self):
        with patch.object(self.verifier, "ARCHIVE_SHA256", self.pin):
            return self.verifier.verify_sources(self.root)

    def test_consistent_host_fixture_compares_nineteen_original_inputs(self):
        self.assertEqual(len(self.verify()["inputs"]), 19)

    def test_wrong_archive_rejected_before_reading_members(self):
        self.archive.write_bytes(b"NOT THE PINNED ARCHIVE")
        with self.assertRaisesRegex(RuntimeError, "pinned official"):
            self.verify()

    def test_modified_internal_tcb_header_rejected(self):
        (self.root / "third_party/musl-1.2.5/src/internal/pthread_impl.h").write_text("changed\n")
        with self.assertRaisesRegex(RuntimeError, "modified musl TCB source"):
            self.verify()

    def test_modified_installed_pthread_header_rejected(self):
        (self.root / "build/musl-rv32-sysroot/usr/include/pthread.h").write_text("changed\n")
        with self.assertRaisesRegex(RuntimeError, "installed musl header differs"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
