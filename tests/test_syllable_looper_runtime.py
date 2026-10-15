# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only input/validator fixtures, not evidence of a guest boot."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


runner = module("looper_runtime_guards", ROOT / "scripts/test-graphics.py")


class LooperRuntimeGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT A BOOT\n"
            "[syllable-looper-gate-A] GNU native ELF exception TLS workers=16 throws=160000 unwind-destructors=160000 static-init=1 independent contexts cpu=0 PASS\n"
            "[syllable-looper-gate-B] original loops=16 targeted typed messages=160000 Handler dispatch and graceful native reaping; non-owned handlers detached PASS\n"
            "[syllable-looper-gate-C] live original timers=64 wake<250000us; malformed=64 node-unsupported=64; common/local discards=64/64; pending timer removal=64 recursive termination=64 filters deleted=128 PASS\n"
            "[syllable-looper] created=reaped=96 faults=0 cancelled=0 active-scopes=0 waiters=0 PASS\n"
            "[syllable-looper] gates A-C PASS; original event loop, not complete AppServer/Desktop\n")

    def test_complete_host_fixture(self):
        self.assertEqual(len(runner.validate_looper_log(self.text, "C")), 3)

    def test_partial_or_incorrect_progress_rejected(self):
        changes = (("workers=16", "workers=15"), ("throws=160000", "throws=159999"),
                   ("unwind-destructors=160000", "unwind-destructors=159999"),
                   ("static-init=1", "static-init=2"), ("cpu=0", "cpu=1"),
                   ("messages=160000", "messages=159999"),
                   ("timers=64", "timers=63"), ("malformed=64", "malformed=63"),
                   ("discards=64/64", "discards=64/63"),
                   ("pending timer removal=64", "pending timer removal=63"),
                   ("recursive termination=64", "recursive termination=63"),
                   ("filters deleted=128", "filters deleted=127"),
                   ("created=reaped=96", "created=reaped=95"),
                   ("faults=0", "faults=1"), ("cancelled=0", "cancelled=1"),
                   ("active-scopes=0", "active-scopes=1"), ("waiters=0", "waiters=1"),
                   ("not complete AppServer/Desktop", "complete AppServer/Desktop"))
        for old, new in changes:
            with self.subTest(changed=old), self.assertRaises(RuntimeError):
                runner.validate_looper_log(self.text.replace(old, new), "C")

    def test_terminal_failure_overrides_pass_markers(self):
        for failure in ("[syllable-looper] FAIL cleanup\n", "SYLLABLE_LOOPER_STATUS=139\r\n"):
            with self.subTest(failure=failure), self.assertRaises(RuntimeError):
                runner.validate_looper_log(self.text + failure, "C")

    def test_exact_native_gnu_tls_layout_not_emulated_or_fixture_tls(self):
        data = bytearray(116)
        data[:7] = b"\x7fELF\x01\x01\x01"
        struct.pack_into("<HH", data, 16, 2, 243)
        struct.pack_into("<I", data, 28, 52)
        struct.pack_into("<HH", data, 42, 32, 2)
        struct.pack_into("<8I", data, 52, 1, 0, 0, 0, len(data), len(data), 5, 4096)
        struct.pack_into("<8I", data, 84, 7, 0, 0, 0, 0, 8, 4, 4)
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="looper-tls-host-") as directory:
            elf = Path(directory) / "fixture.elf"
            elf.write_bytes(data)
            runner.verify_looper_elf(elf)
            for field, value in ((100, 4), (104, 0), (112, 16)):
                changed = bytearray(data)
                struct.pack_into("<I", changed, field, value)
                elf.write_bytes(changed)
                with self.subTest(field=field), self.assertRaises(RuntimeError):
                    runner.verify_looper_elf(elf)

    def test_gnu_prepared_source_tampering_rejected(self):
        preparer = module("gnu_context_tamper", ROOT / "scripts/prepare-native-cxx-context.py")
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="gnu-context-host-") as directory:
            root = Path(directory)
            (root / "build").mkdir()
            (root / "build/cxx-source-manifest.json").write_text(json.dumps({"files": {"eh_globals.cc": "0" * 64}}))
            source = root / "third_party/gcc-15.1.0/eh_globals.cc"
            source.parent.mkdir(parents=True)
            source.write_bytes(b"HOST ONLY TAMPERED SOURCE")
            with patch.object(preparer, "ROOT", root), patch.object(preparer, "OUT", root / "build/context"), \
                    patch.object(preparer, "FILES", {"eh_globals.cc": "0" * 64}), patch.object(preparer.subprocess, "run"):
                with self.assertRaisesRegex(RuntimeError, "modified genuine GNU context input"):
                    preparer.main()

    def test_native_variant_preserves_real_gnu_implementations(self):
        builder = (ROOT / "scripts/build-native-cxx-context.ps1").read_text()
        for flag in ("--target=riscv32-unknown-linux-musl", "-fno-emulated-tls", "-ftls-model=local-exec", "-D_GLIBCXX_EH_POOL_NOBJS=0"):
            self.assertIn(flag, builder)
        context = (ROOT / "ports/syllable/native/cxx_context.c").read_text()
        for function in ("__real__Unwind_Find_FDE", "__real___cxa_guard_acquire", "__real___cxa_guard_release", "__real___cxa_guard_abort"):
            self.assertIn(function, context)
        self.assertLess(context.index("caribe_heap_scope_enter()"), context.index("__atomic_compare_exchange_n"))
        self.assertIn("caribe_heap_scope_leave()", context)
        self.assertNotIn("__cxa_get_globals(void)", context)

    def test_lgpl_runtime_patch_fixes_filter_ownership_and_bounded_decode(self):
        text = (ROOT / "ports/syllable/patches/looper-runtime-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", text)
        self.assertNotIn("BSD-2-Clause", text)
        self.assertIn("+\tif( !pcFilter->m_bGlobalFilter )", text)
        self.assertIn("nReceived ) < 0", text)
        self.assertIn("+\t\t\t\twhile( GetLockCount() > 1 ) Unlock();", text)
        self.assertIn("+\t\t\t\twhile( wait_for_thread( hThread ) < 0 )", text)
        self.assertNotIn("+class Looper", text)

    def test_public_runner_forwards_separate_opt_in(self):
        public = (ROOT / "testproject.ps1").read_text()
        self.assertIn("-SyllableLooper:$SyllableLooper -LooperGate $LooperGate", public)
        make = (ROOT / "Makefile").read_text()
        self.assertIn("build/initrd-looper.img: build/initrd-heap.img", make)
        self.assertIn("build/native-cxx-context/eh_globals.o", make)
        self.assertIn("CXX_CONTEXT_WRAP =", make)


if __name__ == "__main__":
    unittest.main()
