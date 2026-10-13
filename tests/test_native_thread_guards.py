# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only ABI/evidence guards. Fixtures never establish a real kernel PASS."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("thread_collector", ROOT / "tools/collect-native-thread-evidence.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class NativeThreadGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="thread-host-guard-")
        self.source = Path(self.directory.name)
        self.current = {"xnu": "fixture-kernel", "initrd": "fixture-initrd", "nativeThreadProbe": "fixture-probe"}
        self.result = {"result": "PASS", "baseIsa": "rv32imac", "smp": 2, "bios": "default",
                       "nativeThreads": {"gates": list("ABCD"), "enabled": True, "libcThreading": False, "gnuThreadTls": False},
                       "nativeCxx": {"threadModel": "single"}, "artifactSha256": self.current.copy(), "screenshots": {}}
        for name in ("nativeIpc", "nativeAreas", "syllableString", "syllableMessage", "nativeSync", "freetype"):
            self.result[name] = True
        self.serial = ("HOST-ONLY EVIDENCE GUARD FIXTURE, NOT A REAL BOOT\n"
                       "Bash exited status=0 and PID1 reaped PID2 PASS\n"
                       "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS\n"
                       "same-pmap semaphore rounds=10000 acquisitions=20000 releases=20000 scheduler-waits=1\n"
                       "owner-exit cycles=16; created=reaped=35 preemptions=1 PASS\n"
                       "foreign process START/CANCEL/INFO/JOIN denied=64 owner unchanged PASS\n")
        for prefix, gates in collector.PREFIXES:
            for gate in gates:
                (self.source / f"gate-{prefix}-{gate}.txt").write_text("HOST GUARD FIXTURE PASS\n")

    def tearDown(self):
        self.directory.cleanup()

    def validate(self):
        (self.source / "result.json").write_text(json.dumps(self.result))
        (self.source / "serial.txt").write_text(self.serial)
        return collector.validate_case(self.source, self.current)

    def test_consistent_host_fixture_validates_guards_only(self):
        self.validate()

    def test_running_result_is_rejected(self):
        self.result["result"] = "RUNNING"
        with self.assertRaisesRegex(RuntimeError, "incomplete"):
            self.validate()

    def test_stale_kernel_is_rejected(self):
        self.result["artifactSha256"]["xnu"] = "old"
        with self.assertRaisesRegex(RuntimeError, "stale xnu"):
            self.validate()

    def test_partial_thread_gates_are_rejected(self):
        self.result["nativeThreads"]["gates"] = list("ABC")
        with self.assertRaisesRegex(RuntimeError, "incomplete raw-thread"):
            self.validate()

    def test_false_threaded_gnu_claim_is_rejected(self):
        self.result["nativeCxx"]["threadModel"] = "posix"
        with self.assertRaisesRegex(RuntimeError, "GNU thread model"):
            self.validate()

    def test_false_libc_tls_claim_is_rejected(self):
        self.result["nativeThreads"]["libcThreading"] = True
        with self.assertRaisesRegex(RuntimeError, "unsupported libc"):
            self.validate()

    def test_lifecycle_counters_required(self):
        self.serial = self.serial.replace("created=reaped=35", "created=35 reaped=34")
        with self.assertRaisesRegex(RuntimeError, "lifecycle"):
            self.validate()

    def test_selected_dependency_required(self):
        self.result["syllableMessage"] = None
        with self.assertRaisesRegex(RuntimeError, "selected dependency"):
            self.validate()

    def test_owner_rejections_required(self):
        self.serial = self.serial.replace("denied=64", "denied=63")
        with self.assertRaisesRegex(RuntimeError, "ownership rejection"):
            self.validate()

    def test_scanout_path_traversal_rejected(self):
        self.result["screenshots"] = {"../invalid.png": "invalid"}
        with self.assertRaisesRegex(RuntimeError, "scanout"):
            self.validate()

    def test_failed_matrix_keeps_prior_retained_snapshot(self):
        root = self.source / "runtime"
        case = root / "build/graphics-tests" / collector.CASES[0]
        case.mkdir(parents=True)
        (case / "result.json").write_text('{"result":"RUNNING"}')
        out = self.source / "retained"
        out.mkdir()
        sentinel = out / "last-stable.txt"
        sentinel.write_text("HOST GUARD SNAPSHOT\n")
        with patch.object(collector, "ROOT", root), patch.object(collector, "OUT", out), \
             patch.object(collector, "current_artifacts", return_value=self.current):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                collector.main()
        self.assertEqual(sentinel.read_text(), "HOST GUARD SNAPSHOT\n")
        self.assertEqual(list(out.iterdir()), [sentinel])

    def test_uapi_is_exactly_32_words(self):
        source = (ROOT / "include/uapi/caribe_thread.h").read_text()
        body = source.split("struct caribe_thread_request {", 1)[1].split("};", 1)[0]
        words = 0
        for line in re.findall(r"uint32_t\s+([^;]+);", body):
            for field in line.split(","):
                array = re.search(r"\[(\d+)\]", field)
                words += int(array.group(1)) if array else 1
        self.assertEqual(words * 4, 128)
        self.assertIn("CARIBE_THREAD_MAX 16U", source)

    def test_windows_powershell_utf16_log_is_read_without_altering_bytes(self):
        path = self.source / "shell.txt"
        data = "OK: boot_stage1\r\n".encode("utf-16")
        path.write_bytes(data)
        self.assertEqual(collector.read_shell_log(path), "OK: boot_stage1\r\n")
        self.assertEqual(path.read_bytes(), data)

    def test_kernel_and_runtime_wire_abi_match(self):
        candidates = (ROOT.parent.parent / "xnu-2050.48.11/osfmk/riscv32/native_thread.h",
                      ROOT.parent / "xnu/osfmk/riscv32/native_thread.h")
        kernel = next((path for path in candidates if path.exists()), None)
        if kernel is None:
            self.skipTest("paired XNU source required for cross-repository ABI guard")
        def declarations(path):
            return path.read_text().split("#ifndef CARIBE_NATIVE_THREAD_H", 1)[1].split("#ifdef KERNEL", 1)[0].strip().removesuffix("#endif").strip()
        self.assertEqual(declarations(kernel), declarations(ROOT / "include/uapi/caribe_thread.h"))


if __name__ == "__main__":
    unittest.main()
