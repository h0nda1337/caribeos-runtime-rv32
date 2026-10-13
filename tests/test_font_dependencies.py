# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only supply-chain/scanout guards; these are not guest kernel tests."""
import importlib.util
import io
import hashlib
from pathlib import Path
import struct
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


deps = module("font_deps", "prepare-font-deps.py")
runner = module("font_runner", "test-graphics.py")


class FontGuards(unittest.TestCase):
    def test_logged_build_retains_diagnostics_and_failure_exit_codes(self):
        result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                 str(ROOT / "tests/test_logged_graphics_build.ps1")],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("explicit exit codes; no QEMU launched", result.stdout)

    def font_archive(self, root, extra=None):
        archive = root / "third_party/ttf-bitstream-vera-1.10.tar.gz"
        archive.parent.mkdir(parents=True)
        with tarfile.open(archive, "w:gz") as stream:
            for name in ("COPYRIGHT.TXT", "Vera.ttf", "VeraBd.ttf", "VeraMono.ttf"):
                data = b"host-only fixture, never distributed as a real font"
                info = tarfile.TarInfo("ttf-bitstream-vera-1.10/" + name)
                info.size = len(data)
                stream.addfile(info, io.BytesIO(data))
            if extra:
                info = tarfile.TarInfo("ttf-bitstream-vera-1.10/" + extra)
                info.size = 1
                stream.addfile(info, io.BytesIO(b"x"))
        return deps.digest(archive.read_bytes())

    def test_cached_font_archive_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            root = Path(directory)
            self.font_archive(root)
            with patch.object(deps, "ROOT", root), patch.object(deps, "FONT_SOURCE", root / "fonts"):
                with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
                    deps.prepare_fonts()
            self.assertFalse((root / "fonts").exists())

    def test_modified_font_is_not_overwritten(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            root = Path(directory)
            checksum = self.font_archive(root)
            fonts = root / "fonts"; fonts.mkdir()
            target = fonts / "Vera.ttf"; target.write_bytes(b"local modification")
            with patch.object(deps, "ROOT", root), patch.object(deps, "FONT_SOURCE", fonts), \
                    patch.object(deps, "FONT_SHA256", checksum):
                with self.assertRaisesRegex(RuntimeError, "overwrite modified"):
                    deps.prepare_fonts()
            self.assertEqual(target.read_bytes(), b"local modification")
            self.assertFalse((fonts / "COPYRIGHT.TXT").exists())

    def test_archive_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            root = Path(directory)
            checksum = self.font_archive(root, "../../escape")
            with patch.object(deps, "ROOT", root), patch.object(deps, "FONT_SOURCE", root / "fonts"), \
                    patch.object(deps, "FONT_SHA256", checksum):
                with self.assertRaisesRegex(RuntimeError, "unsafe Vera archive path"):
                    deps.prepare_fonts()
            self.assertFalse((root / "escape").exists())

    def test_source_commit_and_untracked_files_are_rejected(self):
        def clean(*args):
            if args == ("rev-parse", "HEAD"): return (deps.COMMIT + "\n").encode()
            if args == ("rev-parse", deps.TAG): return (deps.TAG_OBJECT + "\n").encode()
            if args[0] == "status": return b"?? injected.c\n"
            self.fail(f"unexpected git call: {args}")
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory, \
                patch.object(deps, "SOURCE", Path(directory)):
            with patch.object(deps, "git", return_value=b"bad commit\n"):
                with self.assertRaisesRegex(RuntimeError, "immutable pin"):
                    deps.prepare_freetype()
            with patch.object(deps, "git", side_effect=clean):
                with self.assertRaisesRegex(RuntimeError, "untracked FreeType"):
                    deps.prepare_freetype()

    def check_blob(self, actual, payload, error=None):
        original = b"original input\n"
        object_id = hashlib.sha1(b"blob " + str(len(original)).encode() + b"\0" + original).hexdigest().encode()
        def git_fixture(*args, input=None):
            if args == ("rev-parse", "HEAD"): return (deps.COMMIT + "\n").encode()
            if args == ("rev-parse", deps.TAG): return (deps.TAG_OBJECT + "\n").encode()
            if args[0] == "status": return b""
            if args == ("ls-tree", "-rz", "HEAD"): return b"100644 blob " + object_id + b"\tinput.c\0"
            if args == ("cat-file", "--batch"):
                self.assertEqual(input, object_id + b"\n")
                return object_id + b" blob " + str(len(payload)).encode() + b"\n" + payload + b"\n"
            self.fail(f"unexpected Git call: {args}")
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            source = Path(directory); (source / "input.c").write_bytes(actual)
            with patch.object(deps, "SOURCE", source), patch.object(deps, "git", side_effect=git_fixture):
                if error:
                    with self.assertRaisesRegex(RuntimeError, error): deps.prepare_freetype()
                else:
                    record = deps.prepare_freetype()
                    self.assertEqual(record["files"], [{"path": "input.c", "sha256": deps.digest(original)}])

    def test_only_checkout_crlf_is_normalized(self):
        self.check_blob(b"original input\r\n", b"original input\n")

    def test_clean_git_status_does_not_bypass_content_verification(self):
        self.check_blob(b"modified input\n", b"original input\n", "content differs")

    def test_corrupt_git_blob_is_rejected(self):
        self.check_blob(b"original input\n", b"tampered blob\n", "object content/hash mismatch")

    def test_scanout_hash_uses_guest_xrgb_word_order(self):
        image = Image.new("RGB", (2, 1))
        image.putdata([(0x12, 0x34, 0x56), (0x87, 0x65, 0x43)])
        expected = ((2166136261 ^ 0x123456) * 16777619) & 0xffffffff
        expected = ((expected ^ 0x876543) * 16777619) & 0xffffffff
        self.assertEqual(runner.scanout_fnv(image), expected)
        self.assertTrue(runner.guest_failure("[freetype] FAIL line=10 errno=0"))

    def test_static_soft_float_elf_guards(self):
        elf = bytearray(84); elf[:7] = b"\x7fELF\x01\x01\x01"
        struct.pack_into("<HH", elf, 16, 2, 243)
        struct.pack_into("<I", elf, 28, 52)
        struct.pack_into("<HH", elf, 42, 32, 1)
        struct.pack_into("<I", elf, 52, 1)
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            target = Path(directory) / "probe.elf"; target.write_bytes(elf)
            runner.verify_font_elf(target)
            struct.pack_into("<I", elf, 36, 4); target.write_bytes(elf)
            with self.assertRaisesRegex(RuntimeError, "soft-float"):
                runner.verify_font_elf(target)
            struct.pack_into("<I", elf, 36, 0)
            struct.pack_into("<I", elf, 52, 3); target.write_bytes(elf)
            with self.assertRaisesRegex(RuntimeError, "dynamic loader"):
                runner.verify_font_elf(target)


if __name__ == "__main__":
    unittest.main()
