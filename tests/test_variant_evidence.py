# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Fail-closed host fixtures for retention, not actual original GUI execution."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def collector():
    spec = importlib.util.spec_from_file_location("variant_evidence_guards", ROOT / "tools/collect-syllable-variant-evidence.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class VariantEvidence(unittest.TestCase):
    def test_progressive_and_full_firmware_topologies(self):
        p = collector()
        self.assertEqual(len(p.CASES), 5)
        self.assertEqual([case[2] for case in p.CASES], list("ABCCC"))
        for name, slug, gate, full in p.CASES[2:]:
            self.assertTrue(full)
            self.assertIn("native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c", name)
            self.assertIn("freetype-d-looper-c-messenger-c-variant-c", name)
        self.assertEqual([case[1] for case in p.CASES[2:]], ["opensbi-1", "opensbi-2", "securesbi-2"])

    def test_missing_case_does_not_create_success_directory(self):
        p = collector()
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="variant-proof-host-") as directory:
            root = Path(directory)
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "retained"), \
                    patch.object(p, "CASES", [("HOST-ABSENT-NOT-A-BOOT", "up-a", "A", False)]), \
                    patch.object(p, "current_artifacts", return_value={}), patch.object(sys, "argv", ["collector"]):
                with self.assertRaises(FileNotFoundError):
                    p.main()
                self.assertFalse((root / "retained").exists())

    def test_duplicate_and_partial_rebuild_rejected(self):
        p = collector()
        rows = [{"path": "build/initrd-variant.img", "sha256": "0" * 64}] * 7
        record = {"result": "PASS", "before": rows, "after": rows,
                  "preservedStableArtifacts": 38, "preservedDispatchArtifacts": 20, "kernelRecompiled": False,
                  "forcedRuntimeUnits": ["variant.cpp", "message.cpp", "syllable_variant_probe.cpp"]}
        with self.assertRaisesRegex(RuntimeError, "complete actual Variant forced rebuild"):
            p.validate_rebuild(record)
        self.assertEqual(len(p.REBUILD_PATHS), 7)

    def test_missing_original_profile_rejected(self):
        p = collector()
        with patch.object(p.dispatch, "validate_case", return_value=({"result": "PASS"}, "HOST ONLY")):
            with self.assertRaisesRegex(RuntimeError, "original Variant profile"):
                p.validate_case(Path("HOST-NOT-A-BOOT"), {}, "C", True)

    def test_retention_requires_source_and_full_runtime_before_writes(self):
        text = (ROOT / "tools/collect-syllable-variant-evidence.py").read_text()
        for token in ("dispatch.verify_sources()", "runner.verify_looper_elf", '"fullDesktopCompleted": False',
                      '"priorLongKernelSuitesReexecuted": False', "failure_source.read_text()", "variant-b-guard-channel-failure-20261015"):
            self.assertIn(token, text)
        self.assertLess(text.index("validate_rebuild(rebuild)"), text.index("OUT.mkdir"))

    def test_windows_matrix_uses_versioned_cli_and_stops_at_failure(self):
        text = (ROOT / "scripts/test-syllable-variant-matrix.ps1").read_text()
        self.assertIn("tools/collect-syllable-variant-evidence.py --check-case $Case", text)
        self.assertNotIn("& $PythonPath -c", text)
        self.assertIn("stable baseline was not promoted", text)

    def test_idempotent_preparer_does_not_hide_unbuilt_objects(self):
        text = (ROOT / "scripts/test-syllable-variant-rebuild.ps1").read_text()
        self.assertIn("-W build/syllable-variant/sources.json", text)
        self.assertIn("$compileLog.Contains($token)", text)
        self.assertIn(".Replace('\\','/')", text)
        for unit in ("variant.cpp", "message.cpp", "syllable_variant_probe.cpp"):
            self.assertIn(unit, text)


if __name__ == "__main__":
    unittest.main()
