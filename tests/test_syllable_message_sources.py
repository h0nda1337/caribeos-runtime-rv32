# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only Message source/profile/provenance guards, not kernel simulations."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("message_preparer", ROOT / "scripts/prepare-syllable-message.py")
preparer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preparer)


class SourceGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="message-source-guard-")
        self.root = Path(self.directory.name)
        for relative in preparer.FILES:
            target = self.root / "third_party/syllable" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "build/syllable-message/upstream" / relative, target)
        for relative in ("ports/syllable/COPYING.LIB", "ports/syllable/patches/message-rv32.patch"):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        preparer.subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self):
        self.directory.cleanup()

    def prepare(self):
        with patch.object(preparer, "ROOT", self.root), \
                patch.object(preparer, "OUT", self.root / "build/syllable-message"), \
                contextlib.redirect_stdout(io.StringIO()):
            preparer.main()

    def test_cached_build_keeps_identical_outputs(self):
        self.prepare()
        outputs = [self.root / "build/syllable-message" / name for name in
                   ("message.cpp", "include/util/message.h", "sources.json", "COPYING.LIB")]
        before = [(path.read_bytes(), path.stat().st_mtime_ns) for path in outputs]
        self.prepare()
        self.assertEqual(before, [(path.read_bytes(), path.stat().st_mtime_ns) for path in outputs])

    def test_modified_upstream_is_rejected(self):
        path = self.root / "third_party/syllable" / next(iter(preparer.FILES))
        path.write_bytes(path.read_bytes() + b"\n// unreviewed modification\n")
        with self.assertRaisesRegex(RuntimeError, "source hash mismatch"):
            self.prepare()

    def test_license_and_excluded_profile_are_explicit(self):
        self.prepare()
        out = self.root / "build/syllable-message"
        original = (out / "upstream/system/sys/appserver/libsyllable/util/message.cpp").read_text()
        notice = original[:original.index("*/") + 2]
        self.assertIn(notice, (out / "message.cpp").read_text())
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", (out / "message.cpp").read_text())
        record = json.loads((out / "sources.json").read_text())
        self.assertEqual(record["compiledProfile"], "CARIBE_SYLLABLE_MESSAGE_CORE")
        self.assertIn("Looper/Handler delivery", record["excluded"])
        self.assertEqual(record["maxWireBytes"], 8192)
        for name in ("util/flattenable.h", "util/typecodes.h", "gui/point.h", "gui/rect.h", "gui/gfxtypes.h"):
            self.assertEqual((out / "include" / name).read_bytes(),
                             (out / "upstream/system/sys/include" / name).read_bytes())


if __name__ == "__main__":
    unittest.main()
