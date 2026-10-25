# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only inventory/source guards, never evidence of a running AppServer."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def auditor():
    spec = importlib.util.spec_from_file_location("server_compile_guards", ROOT / "scripts/audit-syllable-server-compile.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class ServerCompilationGuards(unittest.TestCase):
    def test_inventory_does_not_silently_skip_unported_x86_units(self):
        p = auditor()
        names = "ddriver ddline ddmemory event vesadrv server input config keyboard keymap defaultkeymap sapplication swindow layer toplayer render bitmap crdtrans sfont fontnode wndborder desktop winselect sprite clipboard windowdecorator defaultdecorator".split()
        # Host-only Makefile fixture, not a compilation or a fetched upstream file.
        separator = " " + chr(92) + "\n  "
        data = ("OBJS = " + separator.join(name + ".o" for name in names) + "\nOBJS += screenshot.o\n").encode()
        self.assertEqual(p.inventory(data), names)
        for changed in (names[:-1], names[:-1] + [names[0]], names[:-1] + ["../outside"]):
            with self.assertRaisesRegex(RuntimeError, "unexpected original AppServer inventory"):
                p.inventory(("OBJS = " + " ".join(name + ".o" for name in changed)).encode())

    def test_platform_header_is_declarations_only_not_a_backend(self):
        text = (ROOT / "ports/syllable/server-native/atheos/kernel.h").read_text()
        self.assertIn("SPDX-License-Identifier: BSD-2-Clause", text)
        self.assertIn("#define EOK 0", text)
        self.assertIn("#include <atheos/msgport.h>", text)
        self.assertNotIn("return ", text)
        self.assertNotIn("#include <atheos/v86.h>", text)

    def test_source_identity_and_incomplete_runtime_boundary_are_explicit(self):
        text = (ROOT / "scripts/audit-syllable-server-compile.py").read_text()
        for token in ("helpers.verify_header", "units = inventory(makefile)", '"sourcesModified": False',
                      '"displayBackendPorted": False', '"appServerRunning": False',
                      '"runtimeVerified": False', "return 0 if complete else 1", "licenseReviewRequired"):
            self.assertIn(token, text)
        self.assertNotIn('"build/syllable-port"', text)
        self.assertNotIn("-Wno-narrowing", text)
        self.assertNotIn("-fpermissive", text)


if __name__ == "__main__":
    unittest.main()
