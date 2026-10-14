# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Source/compilation guards only, not Looper runtime tests."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def inputs():
    spec = importlib.util.spec_from_file_location("looper_input_fixture", ROOT / "scripts/prepare-syllable-looper.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class LooperInputs(unittest.TestCase):
    def test_complete_upstream_units_and_headers_pinned(self):
        p = inputs()
        self.assertEqual(p.REV, "579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(len(p.FILES), 10)
        for name in ("handler", "looper", "messagefilter"):
            self.assertIn("system/sys/appserver/libsyllable/util/" + name + ".cpp", p.FILES)
            self.assertIn("system/sys/include/util/" + name + ".h", p.FILES)
        self.assertTrue(all(len(digest) == 64 for digest in p.FILES.values()))

    def test_corrupted_cached_source_rejected_without_fetch_or_overwrite(self):
        p = inputs()
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="looper-input-host-") as directory:
            root = Path(directory)
            relative = "system/sys/appserver/libsyllable/util/looper.cpp"
            cached = root / "build/upstream" / relative
            cached.parent.mkdir(parents=True)
            cached.write_bytes(b"HOST ONLY TAMPERED SOURCE")
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "build"), \
                 patch.object(p, "FILES", {relative: "0" * 64}), patch.object(p, "urlopen") as fetch:
                with self.assertRaisesRegex(RuntimeError, "source hash mismatch"):
                    p.main()
                fetch.assert_not_called()
                self.assertEqual(cached.read_bytes(), b"HOST ONLY TAMPERED SOURCE")

    def test_changed_original_prepared_copy_not_silently_reset(self):
        p = inputs()
        data = b"HOST ONLY SYNTHETIC SOURCE NOT UPSTREAM"
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="looper-input-host-") as directory:
            root = Path(directory)
            relative = "system/sys/appserver/libsyllable/util/looper.cpp"
            cached = root / "build/upstream" / relative
            cached.parent.mkdir(parents=True)
            cached.write_bytes(data)
            prepared = root / "build/src/looper.cpp"
            prepared.parent.mkdir()
            prepared.write_bytes(b"HOST ONLY LOCAL MODIFICATION")
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "build"), \
                 patch.object(p, "FILES", {relative: hashlib.sha256(data).hexdigest()}):
                with self.assertRaisesRegex(RuntimeError, "unreviewed change"):
                    p.main()
                self.assertEqual(prepared.read_bytes(), b"HOST ONLY LOCAL MODIFICATION")

    def test_library_patches_keep_lgpl_and_do_not_define_replacement_classes(self):
        for name in ("handler-rv32.patch", "looper-platform-rv32.patch"):
            text = (ROOT / "ports/syllable/patches" / name).read_text()
            self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", text)
            self.assertNotIn("BSD-2-Clause", text)
            self.assertNotIn("+class Looper", text)
            self.assertNotIn("+class Handler", text)

    def test_handler_token_increment_is_atomic(self):
        self.assertIn("__atomic_fetch_add( &nLastToken, 1U, __ATOMIC_SEQ_CST )",
                      (ROOT / "ports/syllable/patches/handler-rv32.patch").read_text())

    def test_audit_does_not_claim_link_or_runtime_success(self):
        text = (ROOT / "scripts/audit-syllable-looper-compile.py").read_text()
        self.assertIn('"linked": False, "runtimeVerified": False', text)
        self.assertIn('"nodeMonitorImplemented": False', text)
        self.assertIn('"COMPILED" if result.returncode == 0 else "BLOCKED"', text)
        self.assertIn('header[18:20] != b"\\xf3\\x00"', text)

    def test_failed_compilation_cannot_be_retained_as_success(self):
        text = (ROOT / "scripts/audit-syllable-looper-compile.py").read_text()
        self.assertLess(text.index('if record["result"] != "COMPILED"'), text.index("evidence.mkdir"))
        self.assertIn("refusing to retain incomplete compilation", text)

    def test_arch_compiler_and_shell_are_explicit_not_windows_aliases(self):
        text = (ROOT / "scripts/audit-syllable-looper-compile.py").read_text()
        self.assertIn('workspace / "msys64/usr/bin/bash.exe"', text)
        self.assertIn('workspace / "msys64/ucrt64/bin/riscv64-unknown-elf-g++.exe"', text)
        self.assertIn('command = [str(bash),', text)


if __name__ == "__main__":
    unittest.main()
