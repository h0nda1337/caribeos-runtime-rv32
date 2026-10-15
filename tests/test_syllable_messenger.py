# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host fixtures/input guards only; never a substitute for guest IPC tests."""
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


runner = module("messenger_runner_fixture", ROOT / "scripts/test-graphics.py")


class MessengerGuards(unittest.TestCase):
    def setUp(self):
        self.text = (
            "HOST ONLY FIXTURE, NOT A BOOT\n"
            "[syllable-messenger-gate-A] original Messenger sync=10000 async Handler replies=10000 reply-to-reply=64; loops=5 created=reaped=5 faults=0 cpu=0 PASS\n"
            "[syllable-messenger-gate-B] ports exhausted=32 no request posted; send/reply deadlines=2 preserved errno; failed late reply retry state retained; ports=0 messages=0 PASS\n"
            "[syllable-messenger-gate-C] independent fork/exec original Looper service; remote typed request/reply=10000 private reply receive ownership; child exit(0) ports=0 messages=0 PASS\n"
            "[syllable-messenger] gates A-C PASS; original toolkit transport, not complete AppServer/Desktop\n")

    def test_complete_host_fixture(self):
        self.assertEqual(len(runner.validate_messenger_log(self.text, "C")), 3)

    def test_incomplete_or_false_success_rejected(self):
        for old, new in (("sync=10000", "sync=9999"), ("replies=10000", "replies=9999"),
                         ("reply-to-reply=64", "reply-to-reply=63"), ("created=reaped=5", "created=reaped=4"),
                         ("faults=0", "faults=1"), ("cpu=0", "cpu=1"), ("exhausted=32", "exhausted=31"),
                         ("deadlines=2", "deadlines=1"), ("ports=0", "ports=1"), ("messages=0", "messages=1"),
                         ("request/reply=10000", "request/reply=9999"), ("child exit(0)", "child exit(1)"),
                         ("private reply receive ownership", "unrestricted receive"),
                         ("not complete AppServer/Desktop", "complete AppServer/Desktop")):
            with self.subTest(changed=old), self.assertRaises(RuntimeError):
                runner.validate_messenger_log(self.text.replace(old, new), "C")

    def test_guest_error_or_nonzero_status_overrides_markers(self):
        for error in ("[syllable-messenger] FAIL child\n", "SYLLABLE_MESSENGER_STATUS=139\r\n"):
            with self.subTest(error=error), self.assertRaises(RuntimeError):
                runner.validate_messenger_log(self.text + error, "C")
        self.assertFalse(runner.guest_failure("SYLLABLE_MESSENGER_STATUS=0\r\n"))

    def test_exact_original_sources_pinned(self):
        p = module("messenger_source_pins", ROOT / "scripts/prepare-syllable-messenger.py")
        self.assertEqual(p.REV, "579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(len(p.FILES), 2)
        self.assertEqual(p.FILES["system/sys/appserver/libsyllable/util/messenger.cpp"],
                         "1a84e4af331cc16674f2458a83005fb5419929b584ccaa3b01e12e9a88087b18")

    def test_corrupt_source_is_not_refetched_or_replaced(self):
        p = module("messenger_tampered_source", ROOT / "scripts/prepare-syllable-messenger.py")
        with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="messenger-host-") as directory:
            root = Path(directory)
            relative = "system/sys/appserver/libsyllable/util/messenger.cpp"
            cached = root / "build/upstream" / relative
            cached.parent.mkdir(parents=True)
            cached.write_bytes(b"HOST ONLY TAMPERED SOURCE")
            with patch.object(p, "ROOT", root), patch.object(p, "OUT", root / "build"), \
                    patch.object(p, "FILES", {relative: "0" * 64}), patch.object(p.subprocess, "run"), \
                    patch.object(p, "urlopen") as fetch:
                with self.assertRaisesRegex(RuntimeError, "original source hash mismatch"):
                    p.main()
                fetch.assert_not_called()
                self.assertEqual(cached.read_bytes(), b"HOST ONLY TAMPERED SOURCE")

    def test_separate_library_and_image_keep_core_variant(self):
        make = (ROOT / "Makefile").read_text()
        self.assertIn("build/initrd-messenger.img: build/initrd-looper.img", make)
        self.assertIn("-DCARIBE_SYLLABLE_MESSAGE_DELIVERY", make)
        self.assertIn("build/libcaribe-syllable-messenger.a:", make)
        self.assertIn("build/libcaribe-syllable-message.a:", make)
        self.assertIn("-c build/syllable-messenger/message.cpp", make)

    def test_patch_preserves_lgpl_and_original_methods(self):
        text = (ROOT / "ports/syllable/patches/messenger-runtime-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", text)
        self.assertNotIn("BSD-2-Clause", text)
        self.assertNotIn("+class Messenger", text)
        for token in ("nSendTimeOut );", "nReplyTimeOut );", "nTimeOut );", "int nSaved = errno;",
                      "m_hReplyPort = hOldPort; m_hReplyProc = hOldProc;", "if( nError == 0 ) m_nFlags |= REPLY_SENT;",
                      "new( std::nothrow ) uint8[8192]"):
            self.assertIn(token, text)
        self.assertNotIn("--unidiff-zero", (ROOT / "scripts/prepare-syllable-messenger.py").read_text())

    def test_real_independent_exec_and_private_receive_probe(self):
        text = (ROOT / "userland/syllable_messenger_probe.cpp").read_text()
        for token in ("pid_t child=fork()", 'execl("/bin/syllable-messenger-probe"', "waitpid(child,&status,0)",
                      "remote && seq==0", "errno==EPERM", "m->SendReply(&reply,&back", "target.SendMessage(&m,&reply"):
            self.assertIn(token, text)
        self.assertIn("loop->SetDefaultHandler(&service)", text)
        self.assertIn("loop->GetDefaultHandler()==&service", text)
        self.assertLess(text.index("if(gate=='C')gate_c_before_workers();"), text.index('"actual heap/native thread activation"'))

    def test_disabled_dependencies_rejected_before_build(self):
        for disabled in ("--native-heap-disabled", "--native-threads-disabled", "--native-futex-disabled"):
            result = subprocess.run([sys.executable, str(ROOT / "scripts/test-graphics.py"), "--syllable-messenger", disabled], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Looper gates require", result.stderr)

    def test_public_runner_forwards_opt_in(self):
        text = (ROOT / "testproject.ps1").read_text()
        self.assertIn("-SyllableMessenger:$SyllableMessenger -MessengerGate $MessengerGate", text)
        leaf = (ROOT / "scripts/qemu-rv32-graphics.ps1").read_text()
        self.assertIn("$SyllableLooper = $SyllableLooper -or $SyllableMessenger", leaf)
        self.assertIn("INITRD_IMG=build/initrd-messenger.img", leaf)


if __name__ == "__main__":
    unittest.main()
