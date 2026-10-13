# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only native header pinning/license guards, not kernel behavior tests."""
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
spec = importlib.util.spec_from_file_location("native_preparer", ROOT / "scripts/prepare-syllable-native.py")
preparer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preparer)


class SourceGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="native-source-guard-")
        self.root = Path(self.directory.name)
        for relative in preparer.FILES:
            target = self.root / "build/syllable-native/upstream" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "build/syllable-native/upstream" / relative, target)
        target = self.root / "ports/syllable/COPYING.LIB"
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "ports/syllable/COPYING.LIB", target)

    def tearDown(self):
        self.directory.cleanup()

    def prepare(self):
        with patch.object(preparer, "ROOT", self.root), \
                patch.object(preparer, "OUT", self.root / "build/syllable-native"), \
                contextlib.redirect_stdout(io.StringIO()):
            preparer.main()

    def test_unchanged_outputs_preserve_timestamps(self):
        self.prepare()
        paths = [self.root / "build/syllable-native" / name for name in
                 ("include/atheos/semaphore.h", "include/atheos/msgport.h", "sources.json", "COPYING.LIB")]
        before = [(path.read_bytes(), path.stat().st_mtime_ns) for path in paths]
        self.prepare()
        self.assertEqual(before, [(path.read_bytes(), path.stat().st_mtime_ns) for path in paths])

    def test_modified_semaphore_header_is_rejected(self):
        target = self.root / "build/syllable-native/upstream/system/sys/include/atheos/semaphore.h"
        target.write_bytes(target.read_bytes() + b"\n/* unreviewed */\n")
        with self.assertRaisesRegex(RuntimeError, "source hash mismatch"):
            self.prepare()

    def test_original_license_and_header_are_unchanged(self):
        self.prepare()
        out = self.root / "build/syllable-native"
        original = (out / "upstream/system/sys/include/atheos/semaphore.h").read_bytes()
        self.assertEqual(original, (out / "include/atheos/semaphore.h").read_bytes())
        self.assertNotIn(b"BSD-2-Clause", original)
        record = json.loads((out / "sources.json").read_text())
        item = next(item for item in record["files"] if item["path"].endswith("/semaphore.h"))
        self.assertTrue(item["compiled"])
        self.assertEqual(item["license"], "LGPL-2.0-only")


if __name__ == "__main__":
    unittest.main()
