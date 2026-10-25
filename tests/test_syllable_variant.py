# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only Variant source and verifier guards, not proof of a guest boot."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


runner = module("variant_runner_guards", ROOT / "scripts/test-graphics.py")


class VariantGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT A BOOT\n"
            "[syllable-variant-gate-A] original class ABI=16 vectors=19 offsets=4 exact-roundtrips=76 canonical wire; deep-copy self/alias and int64 conversions PASS\n"
            "[syllable-variant-gate-B] guard-page truncations=253 deterministic fuzz=4096 shared depth=16; pointer wire denied; allocation failures=5 prior Variant/Message retained PASS\n"
            "[syllable-variant-cross] independent fork/exec original Looper/Messenger typed request/reply=10000 value families=19 child exit(0) PASS\n"
            "[syllable-variant-gate-C] workers=16 typed Variant/Message cycles=160000 cpu=0 created=reaped=16 faults=0 active-scopes=0 waiters=0; cross-exec replies=10000 PASS\n"
            "[syllable-variant] gates A-C PASS; original GUI typed values, not complete Application/AppServer/Desktop\n")

    def test_complete_host_fixture(self):
        self.assertEqual(len(runner.validate_variant_log(self.text, "C")), 3)

    def test_incomplete_or_false_success_rejected(self):
        for old, new in (("ABI=16", "ABI=12"), ("vectors=19", "vectors=18"),
                         ("offsets=4", "offsets=1"), ("roundtrips=76", "roundtrips=75"),
                         ("truncations=253", "truncations=252"), ("fuzz=4096", "fuzz=4095"),
                         ("depth=16", "depth=32"), ("failures=5", "failures=4"),
                         ("cycles=160000", "cycles=159999"), ("cpu=0", "cpu=1"),
                         ("created=reaped=16", "created=reaped=15"), ("faults=0", "faults=1"),
                         ("active-scopes=0", "active-scopes=1"), ("waiters=0", "waiters=1"),
                         ("request/reply=10000", "request/reply=9999"), ("child exit(0)", "child exit(1)"),
                         ("not complete Application/AppServer/Desktop", "complete Application/AppServer/Desktop")):
            with self.subTest(changed=old), self.assertRaises(RuntimeError):
                runner.validate_variant_log(self.text.replace(old, new), "C")

    def test_failure_overrides_success_markers(self):
        for failure in ("[syllable-variant] FAIL teardown\n", "SYLLABLE_VARIANT_STATUS=139\r\n"):
            with self.subTest(failure=failure), self.assertRaises(RuntimeError):
                runner.validate_variant_log(self.text + failure, "C")
        self.assertFalse(runner.guest_failure("SYLLABLE_VARIANT_STATUS=0\r\n"))

    def test_exact_original_inputs(self):
        p = module("variant_pins", ROOT / "scripts/prepare-syllable-variant.py")
        self.assertEqual(p.REV, "579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(p.FILES, {
            "system/sys/appserver/libsyllable/util/variant.cpp": "f85f3591915e8b901eb7ae9da1d2c7a095f6a35cb7861bde539137c94b6f14da",
            "system/sys/include/util/variant.h": "a9c396b0edb90dc93ec20530969ae759b64e5768bafa17888d30c453eebb8bc2"})

    def test_tampered_input_not_refetched_or_overwritten(self):
        p = module("variant_tampering", ROOT / "scripts/prepare-syllable-variant.py")
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="variant-host-") as directory:
            root = Path(directory)
            relative = "system/sys/appserver/libsyllable/util/variant.cpp"
            cached = root / "build/upstream" / relative
            cached.parent.mkdir(parents=True)
            cached.write_bytes(b"HOST ONLY TAMPERED SOURCE")
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "build"), \
                    patch.object(p, "FILES", {relative: "0" * 64}), patch.object(p.sys, "argv", ["prepare"]), \
                    patch.object(p.subprocess, "run"), patch.object(p, "urlopen") as fetch:
                with self.assertRaisesRegex(RuntimeError, "original source hash mismatch"):
                    p.main()
                fetch.assert_not_called()
                self.assertEqual(cached.read_bytes(), b"HOST ONLY TAMPERED SOURCE")

    def test_derived_license_and_shared_depth_not_replacement_classes(self):
        text = (ROOT / "ports/syllable/patches/variant-runtime-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", text)
        self.assertNotIn("BSD-2-Clause", text)
        self.assertNotIn("+class Variant", text)
        self.assertNotIn("+class Message", text)
        self.assertIn("Variant::_ValidateFlattened", text)
        self.assertIn("Message::_ValidateFlattened", text)
        self.assertIn("nDepth + 1", text)
        self.assertIn("8192", text)
        self.assertIn("ENOMEM", text)
        self.assertIn("ENOTSUP", text)

    def test_new_provider_is_opt_in(self):
        make = (ROOT / "Makefile").read_text()
        self.assertIn("build/initrd-variant.img: build/initrd-messenger.img", make)
        self.assertIn("-DCARIBE_SYLLABLE_MESSAGE_VARIANT", make)
        self.assertIn("build/libcaribe-syllable-variant.a:", make)
        self.assertIn("-c build/syllable-variant/message.cpp", make)
        self.assertIn("-Wl,--wrap=_Znaj", make)
        for disabled in ("--native-heap-disabled", "--native-threads-disabled", "--native-futex-disabled"):
            result = subprocess.run([sys.executable, str(ROOT / "scripts/test-graphics.py"), "--syllable-variant", disabled], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Looper gates require", result.stderr)

    def test_original_execution_probe_and_public_runner(self):
        text = (ROOT / "userland/syllable_variant_probe.cpp").read_text()
        for token in ('execl("/bin/syllable-variant-probe"', "waitpid(child,&status,0)",
                      "controller_guard_mprotect(pages+8192)", "stats().live==0", "i<4096", "i<10000",
                      "sizeof(os::Variant)==16", "loop->SetDefaultHandler(&echo)",
                      "__real__Znaj(size)", "__atomic_store_n(&inject_array_failure,1U"):
            self.assertIn(token, text)
        public = (ROOT / "testproject.ps1").read_text()
        self.assertIn("-SyllableVariant:$SyllableVariant -VariantGate $VariantGate", public)
        leaf = (ROOT / "scripts/qemu-rv32-graphics.ps1").read_text()
        self.assertIn("$SyllableMessenger = $SyllableMessenger -or $SyllableVariant", leaf)
        self.assertIn("INITRD_IMG=build/initrd-variant.img", leaf)


if __name__ == "__main__":
    unittest.main()
