# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only source pin/license/rebuild guards, not simulated kernel gates."""
import contextlib
import importlib.util
import io
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("string_preparer", ROOT / "scripts/prepare-syllable-string.py")
preparer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preparer)


class SourceGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="string-source-guard-")
        self.root = Path(self.directory.name)
        for relative in preparer.FILES:
            source = ROOT / "build/syllable-string/upstream" / relative
            target = self.root / "third_party/syllable" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        for relative in ("ports/syllable/COPYING.LIB", "ports/syllable/patches/string-rv32.patch"):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        # A separate local repository makes git apply's working root explicit.
        preparer.subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self):
        self.directory.cleanup()

    def prepare(self):
        with patch.object(preparer, "ROOT", self.root), \
                patch.object(preparer, "OUT", self.root / "build/syllable-string"), \
                contextlib.redirect_stdout(io.StringIO()):
            preparer.main()

    def test_repeat_preserves_output_and_timestamps(self):
        self.prepare()
        outputs = [self.root / "build/syllable-string" / name for name in
                   ("string.cpp", "utf8_length.h", "include/util/string.h", "sources.json", "COPYING.LIB")]
        before = [(path.read_bytes(), path.stat().st_mtime_ns) for path in outputs]
        self.prepare()
        self.assertEqual(before, [(path.read_bytes(), path.stat().st_mtime_ns) for path in outputs])

    def test_modified_cached_source_is_rejected(self):
        target = self.root / "third_party/syllable" / next(iter(preparer.FILES))
        target.write_bytes(target.read_bytes() + b"\n// unexpected edit\n")
        with self.assertRaisesRegex(RuntimeError, "source hash mismatch"):
            self.prepare()

    def test_invalid_patch_does_not_generate_success_manifest(self):
        (self.root / "ports/syllable/patches/string-rv32.patch").write_bytes(b"not a patch\n")
        with self.assertRaises(preparer.subprocess.CalledProcessError):
            self.prepare()
        self.assertFalse((self.root / "build/syllable-string/sources.json").exists())

    def test_original_notices_and_unmodified_public_header_survive(self):
        self.prepare()
        out = self.root / "build/syllable-string"
        original = (out / "upstream/system/sys/appserver/libsyllable/util/string.cpp").read_text()
        notice = original[original.index("/*"):original.index("*/") + 2]
        self.assertIn(notice, (out / "string.cpp").read_text())
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", (out / "string.cpp").read_text())
        self.assertIn("Copyright (C) 2003 - 2004 The Syllable Team", (out / "utf8_length.h").read_text())
        self.assertEqual((out / "include/util/string.h").read_bytes(),
                         (out / "upstream/system/sys/include/util/string.h").read_bytes())


if __name__ == "__main__":
    unittest.main()
