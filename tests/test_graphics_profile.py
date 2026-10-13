# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only runner guards: no kernel behavior is simulated or claimed here."""
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("graphics_runner", ROOT / "scripts/test-graphics.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class ProfileGuards(unittest.TestCase):
    def check_rejected(self, elf, expected):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="profile-guard-") as directory:
            root = Path(directory)
            probe = root / "build/cxx-runtime-probe.elf"
            library = root / "build/cxx-rv32-sysroot/usr/lib/rv32imac/ilp32/libstdc++.a"
            library.parent.mkdir(parents=True)
            library.write_bytes(b"host-only fixture")
            probe.write_bytes(elf)
            result = root / "build/graphics-tests/opensbi-smp1-native-cxx/result.json"
            result.parent.mkdir(parents=True)
            result.write_text('{"result":"PASS","stale":true}\n')
            with patch.object(runner, "ROOT", root), patch.object(runner, "verify_abi"), \
                    patch.object(runner, "build_hashes", return_value={"xnu": "fixture"}), \
                    patch.object(sys, "argv", ["test-graphics.py", "--native-cxx"]), \
                    patch.object(runner.subprocess, "check_output", return_value=""), \
                    patch.object(runner.subprocess, "Popen") as qemu:
                with self.assertRaisesRegex(RuntimeError, expected):
                    runner.run()
                qemu.assert_not_called()
            record = json.loads(result.read_text())
            self.assertEqual(record["result"], "FAIL")
            self.assertNotIn("stale", record)
            self.assertIn("error", record)
            runner.RUN_RESULT_PATH = None

    def test_wrong_elf_does_not_leave_previous_pass(self):
        self.check_rejected(b"not ELF", "not static RV32")

    def test_hard_float_profile_is_rejected_before_qemu(self):
        elf = bytearray(84)
        elf[:7] = b"\x7fELF\x01\x01\x01"
        struct.pack_into("<HH", elf, 16, 2, 243)
        struct.pack_into("<I", elf, 36, 4)
        self.check_rejected(elf, "not static RV32")

    def test_missing_tls_runtime_is_not_claimed_as_tls(self):
        elf = bytearray(84)
        elf[:7] = b"\x7fELF\x01\x01\x01"
        struct.pack_into("<HH", elf, 16, 2, 243)
        struct.pack_into("<I", elf, 28, 52)
        struct.pack_into("<HH", elf, 42, 32, 1)
        struct.pack_into("<I", elf, 52, 1)
        self.check_rejected(elf, "neither native TLS")

if __name__ == "__main__":
    unittest.main()
