# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host guards for truthful original client compilation audits, not GUI proof."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def auditor():
    spec = importlib.util.spec_from_file_location("client_compile_guards", ROOT / "scripts/audit-syllable-client-compile.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class ClientCompilationGuards(unittest.TestCase):
    def test_original_git_blob_and_newline_only_equivalence(self):
        p = auditor()
        self.assertEqual(p.blob(b"hello\n"), "ce013625030ba8dba906f756967f9e9ca394464a")
        expected = p.blob(b"original\nheader\n")
        p.verify_header(b"original\r\nheader\r\n", expected, "fixture.h")
        for data, digest in ((b"changed\nheader\n", expected), (b"anything", None)):
            with self.assertRaisesRegex(RuntimeError, "unverified original header"):
                p.verify_header(data, digest, "fixture.h")

    def test_missing_pinned_clone_fails_before_output(self):
        p = auditor()
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="client-host-") as directory:
            root = Path(directory)
            with patch.object(p, "REPO", root / "absent"), patch.object(p, "OUT", root / "output"), \
                    patch.object(sys, "argv", ["auditor"]), patch.object(p.subprocess, "check_output") as command:
                with self.assertRaisesRegex(RuntimeError, "Pinned upstream audit clone required"):
                    p.main()
                command.assert_not_called()
                self.assertFalse((root / "output").exists())

    def test_real_units_no_decorator_adapter_and_no_runtime_promotion(self):
        text = (ROOT / "scripts/audit-syllable-client-compile.py").read_text()
        for unit in ("application", "invoker", "window", "view", "font", "control"):
            self.assertIn('"' + unit + '"', text)
        self.assertNotIn('"build/syllable-port"', text)
        for token in ('"result": "COMPILED_NOT_LINKED" if complete else "INCOMPLETE"',
                      '"runtimeVerified": False', '"linked": False', "return 0 if complete else 1",
                      "verify_header(data, objects.get(original), alias)", '"sourceSha256": hashlib.sha256(source.read_bytes())',
                      "riscv64-unknown-elf-nm.exe", "GUI client object is not RV32 ELF/soft-float"):
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
