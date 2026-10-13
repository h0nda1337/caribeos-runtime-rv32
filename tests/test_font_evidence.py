# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Synthetic host-only evidence-validator fixtures, not QEMU/kernel results."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("font_collector", ROOT / "tools/collect-font-evidence.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
CASE = "synthetic-host-fixture-only"


class EvidenceGuards(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory) / "workspace/host/runtime"
        build = root / "build"; build.mkdir(parents=True)
        kernel = root.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
        kernel.parent.mkdir(parents=True); kernel.write_bytes(b"host-only kernel fixture")
        current = {"xnu": collector.sha(kernel)}
        paths = (("initrd", "build/initrd-fonts.img"), ("freetypeProbe", "build/freetype-probe.elf"),
                 ("freetypeLibrary", "build/freetype-rv32-sysroot/usr/lib/libfreetype.a"))
        after = []
        for key, name in paths:
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"synthetic host-only fixture")
            current[key] = collector.sha(path); after.append({"path": name, "sha256": current[key]})
        sources = build / "font-sources.json"
        sources.write_text(json.dumps({"freetype": {"commit": "37515cf56ba3349656049edbed89ffc6f6466f2d"}}))
        current["fontSources"] = collector.sha(sources)
        (build / "freetype-rebuild.json").write_text(json.dumps({"result": "PASS", "before": after, "after": after}))
        baseline = root / "docs/evidence/syllable-sync-v0.7/manifest.json"
        baseline.parent.mkdir(parents=True); baseline.write_text(json.dumps({"currentArtifactSha256": {"xnu": current["xnu"]}}))
        source = build / "graphics-tests" / CASE; source.mkdir(parents=True)
        (source / "serial.txt").write_text("Bash exited status=0 and PID1 reaped PID2 PASS\nframe-fnv32=12345678 GPU-present zero-area-leak PASS\n")
        screenshot = source / "00-freetype-fonts.png"; screenshot.write_bytes(b"not a real image: host-only hash fixture")
        result = {"result": "PASS", "baseIsa": "rv32imac", "smp": 1, "artifactSha256": current,
                  "freetype": {"gates": list("ABCD"), "engine": "2.15.0", "appServerBuilt": False,
                               "scanoutFnv32": "12345678", "rasterRounds": 10000, "truncations": 256,
                               "invalidSignatures": 1024, "allocationFailureCases": 32},
                  "screenshots": {screenshot.name: collector.sha(screenshot)}}
        for key in ("nativeSync", "nativeIpc", "nativeAreas", "nativeCxx", "syllableString", "syllableMessage"):
            result[key] = {"hostFixture": True}
        (source / "result.json").write_text(json.dumps(result))
        for prefix, gates in (("freetype", "ABCD"), ("native-sync", "ABCDE"), ("native-ipc", "ABCD"),
                              ("native-area", "ABCDE"), ("native-cxx", "ABCD"),
                              ("syllable-string", "ABCD"), ("syllable-message", "ABCD")):
            for gate in gates:
                (source / f"gate-{prefix}-{gate}.txt").write_text("synthetic host fixture PASS\n")
        out = root / "retained"; out.mkdir(); (out / "previous.txt").write_text("keep prior evidence")
        return root, source, out

    def run_case(self, change=None, error=None):
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="font-evidence-fixture-") as directory:
            root, source, out = self.fixture(directory)
            if change: change(root, source)
            with patch.object(collector, "ROOT", root), patch.object(collector, "OUT", out), \
                    patch.object(collector, "CASES", (CASE,)):
                if error:
                    with self.assertRaisesRegex(RuntimeError, error): collector.main()
                    self.assertEqual(sorted(path.name for path in out.iterdir()), ["previous.txt"])
                else:
                    collector.main()
                    self.assertEqual(json.loads((out / "manifest.json").read_text())["result"], "PASS")
            self.assertEqual((out / "previous.txt").read_text(), "keep prior evidence")

    def test_missing_gate_cannot_overwrite_prior_evidence(self):
        self.run_case(lambda root, source: (source / "gate-freetype-C.txt").write_text(""), "missing gate log")

    def test_changed_library_cannot_reuse_old_pass(self):
        self.run_case(lambda root, source: (root / "build/freetype-rv32-sysroot/usr/lib/libfreetype.a").write_bytes(b"changed"), "stale/unsafe")

    def test_changed_kernel_cannot_reuse_prior_process_regression(self):
        def change(root, source):
            baseline = root / "docs/evidence/syllable-sync-v0.7/manifest.json"
            baseline.write_text('{"currentArtifactSha256":{"xnu":"wrong"}}')
        self.run_case(change, "changed kernel")

    def test_consistent_host_fixture_validates_collector_only(self):
        self.run_case()


if __name__ == "__main__":
    unittest.main()
