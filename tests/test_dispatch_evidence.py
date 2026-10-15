# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Fail-closed retention fixtures only, not actual guest proof."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def collector():
    spec = importlib.util.spec_from_file_location("dispatch_evidence_guards", ROOT / "tools/collect-syllable-dispatch-evidence.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class DispatchEvidence(unittest.TestCase):
    def test_full_topologies_and_original_classes_required(self):
        p = collector()
        self.assertEqual(len(p.CASES), 6)
        self.assertEqual(sum(case[2] for case in p.CASES), 3)
        for name, slug, messenger in p.CASES:
            self.assertIn("native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c", name)
            self.assertIn("freetype-d-looper-c", name)
            self.assertEqual("messenger-c" in name, messenger)

    def test_missing_case_does_not_create_success_directory(self):
        p = collector()
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="dispatch-proof-host-") as directory:
            root = Path(directory)
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "retained"), \
                    patch.object(p, "CASES", [("HOST-ABSENT-NOT-A-BOOT", "opensbi-1", False)]), \
                    patch.object(p, "current_artifacts", return_value={}), patch.object(sys, "argv", ["collector"]):
                with self.assertRaises(FileNotFoundError):
                    p.main()
                self.assertFalse((root / "retained").exists())

    def test_duplicate_or_partial_rebuild_is_not_evidence(self):
        p = collector()
        duplicate = [{"path": "build/initrd-messenger.img", "sha256": "0" * 64}] * 20
        record = {"result": "PASS", "before": duplicate, "after": duplicate, "includesMessenger": True, "preservedStableArtifacts": 38}
        with self.assertRaisesRegex(RuntimeError, "complete actual dispatch forced rebuild"):
            p.validate_rebuild(record)
        self.assertEqual(len(p.REBUILD_PATHS), 20)

    def test_missing_original_looper_profile_rejected(self):
        p = collector()
        with patch.object(p.heap, "validate_case", return_value=({"result": "PASS"}, "HOST ONLY")):
            with self.assertRaisesRegex(RuntimeError, "original Looper profile"):
                p.validate_case(Path("HOST-NOT-A-BOOT"), {}, False)

    def test_source_and_failed_attempt_boundaries_are_explicit(self):
        text = (ROOT / "tools/collect-syllable-dispatch-evidence.py").read_text()
        for marker in ("heap.verify_sources()", "runner.verify_looper_elf", 'record.get("sourcesModified") is not False',
                       '"fullDesktopCompleted": False', '"priorLongKernelSuitesReexecuted": False', '"knownFailedAttempts": failures'):
            self.assertIn(marker, text)
        self.assertLess(text.index("validate_rebuild(rebuild)"), text.index("OUT.mkdir"))

    def test_windows_reuse_uses_versioned_cli_not_inline_python(self):
        text = (ROOT / "scripts/test-syllable-dispatch-matrix.ps1").read_text()
        self.assertIn("tools/collect-syllable-dispatch-evidence.py --check-case $case", text)
        self.assertNotIn("& $PythonPath -c", text)


if __name__ == "__main__":
    unittest.main()
