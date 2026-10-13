# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only evidence guard fixtures; these do not simulate any kernel tests."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sync_evidence", ROOT / "tools/collect-syllable-sync-evidence.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class EvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="sync-evidence-guard-")
        self.root = Path(self.directory.name) / "workspace/runtime/caribeos"
        self.out = self.root / "evidence"
        self.out.mkdir(parents=True)
        self.sentinel = self.out / "prior-snapshot.txt"
        self.sentinel.write_text("Keep the last verified evidence intact.\n")
        kernel = self.root.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
        files = {"xnu": kernel, "initrd": self.root / "build/initrd-sync.img",
                 "nativeSyncProbe": self.root / "build/native-sync-probe.elf",
                 "nativeIpcLibrary": self.root / "build/libcaribe-syllable-native.a"}
        for path in files.values():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"HOST ONLY GUARD FIXTURE; NOT A KERNEL OR REAL RESULT")
        artifacts = {name: collector.sha(path) for name, path in files.items()}
        for case in collector.CASES:
            source = self.root / "build/graphics-tests" / case
            source.mkdir(parents=True)
            serial = "Bash exited status=0 and PID1 reaped PID2 PASS\n[smp-gate-f] fixture PASS\n"
            (source / "serial.txt").write_text(serial)
            (source / "fixture.png").write_bytes(b"not a real scanout; hash guard fixture only")
            result = {"result": "PASS", "nativeSync": {"gates": list("ABCDE")}, "nativeIpc": True,
                      "nativeAreas": True, "nativeCxx": True, "syllableString": True, "syllableMessage": True,
                      "smp": 2 if "smp2" in case else 1, "baseIsa": "rv32imac", "artifactSha256": artifacts,
                      "screenshots": {"fixture.png": collector.sha(source / "fixture.png")}}
            (source / "result.json").write_text(json.dumps(result))
            for prefix, gates in (("native-sync", "ABCDE"), ("native-ipc", "ABCD"),
                                  ("native-area", "ABCDE"), ("native-cxx", "ABCD"),
                                  ("syllable-string", "ABCD"), ("syllable-message", "ABCD")):
                for gate in gates:
                    (source / f"gate-{prefix}-{gate}.txt").write_text("host fixture PASS\n")
        lines = ["OK: boot_stage1"] + ["OK: boot_stage1_process_gate_" + str(i) +
                ("_only" if 7 <= i <= 10 else "") for i in range(2, 16)]
        (self.root / "build/native-sync-process-regression.txt").write_text("\n".join(lines) + "\ntestproject.ps1 completed.\n")
        for name in ("syllable-native", "syllable-message"):
            path = self.root / "build" / name / "sources.json"
            path.parent.mkdir(parents=True)
            path.write_text("{}\n")
        rows = [{"path": "build/native-sync-probe.elf", "sha256": artifacts["nativeSyncProbe"]}]
        (self.root / "build/native-sync-rebuild.json").write_text(json.dumps({"result": "PASS", "before": rows, "after": rows}))

    def tearDown(self):
        self.directory.cleanup()

    def collect(self):
        with patch.object(collector, "ROOT", self.root), patch.object(collector, "OUT", self.out), \
                contextlib.redirect_stdout(io.StringIO()):
            collector.main()

    def untouched(self):
        self.assertEqual(list(self.out.iterdir()), [self.sentinel])

    def test_stale_artifact_is_rejected_before_changing_saved_evidence(self):
        (self.root / "build/native-sync-probe.elf").write_bytes(b"new unverified build")
        with self.assertRaisesRegex(RuntimeError, "stale nativeSyncProbe"):
            self.collect()
        self.untouched()

    def test_missing_process_completion_keeps_last_snapshot(self):
        path = self.root / "build/native-sync-process-regression.txt"
        path.write_text(path.read_text().replace("OK: boot_stage1_process_gate_15\n", ""))
        with self.assertRaisesRegex(RuntimeError, "15 runner targets"):
            self.collect()
        self.untouched()

    def test_nonidentical_rebuild_keeps_last_snapshot(self):
        path = self.root / "build/native-sync-rebuild.json"
        result = json.loads(path.read_text())
        result["after"] = []
        path.write_text(json.dumps(result))
        with self.assertRaisesRegex(RuntimeError, "forced rebuild verification"):
            self.collect()
        self.untouched()

    def test_consistent_host_fixtures_are_retained(self):
        self.collect()
        manifest = json.loads((self.out / "manifest.json").read_text())
        self.assertEqual(manifest["result"], "PASS")
        self.assertEqual(len(manifest["cases"]), 3)
        self.assertIn("not native user threads", manifest["scope"])


if __name__ == "__main__":
    unittest.main()
