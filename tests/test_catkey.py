#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Exercise the same C verifier used by CBX against an independent host signer."""
import ctypes
import hashlib
import importlib.util
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("catkey", ROOT / "tools/catkey.py")
catkey = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catkey)


class CatKeyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = ROOT / "build/security-tests"
        out.mkdir(parents=True, exist_ok=True)
        mono = ROOT / "third_party/monocypher-4.0.2"
        mbed = ROOT / "third_party/mbedtls-3.6.5"
        dll = out / "catkey-test.dll"
        subprocess.run(["gcc", "-shared", "-O2", "-Wall", "-Wextra", "-Werror",
                        "-I.", f"-I{mono / 'src'}", f"-I{mono / 'src/optional'}",
                        f"-I{mbed / 'include'}", f"-I{mbed / 'library'}",
                        '-DMBEDTLS_CONFIG_FILE="security/mbedtls_config.h"',
                        "security/catkey.c", "security/crypto_port.c",
                        str(mono / "src/monocypher.c"),
                        str(mono / "src/optional/monocypher-ed25519.c"),
                        str(mbed / "library/sha256.c"), "-o", str(dll)], cwd=ROOT, check=True)
        cls.lib = ctypes.CDLL(str(dll))
        cls.lib.catkey_verify.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p,
                                         ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
                                         ctypes.c_uint32, ctypes.c_void_p, ctypes.c_void_p,
                                         ctypes.c_void_p, ctypes.c_uint32]
        cls.lib.catkey_sha256.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
        cls.lib.crypto_ed25519_check.argtypes = [ctypes.c_void_p, ctypes.c_void_p,
                                                ctypes.c_void_p, ctypes.c_size_t]

    def setUp(self):
        self.key = catkey.Ed25519PrivateKey.generate()
        self.public = catkey.raw_public(self.key)
        self.payload = b"CaribeOS signed test image\x00" * 100
        self.subject = catkey.subject_bytes("kernel.elf")
        self.nonce = bytes(32)
        self.record = catkey.build_record(self.key, self.payload, self.subject, 1)

    def verify(self, record=None, payload=None, public=None, required=1, kind=1,
               subject=None, nonce=None, role=2, allowed=3):
        record = self.record if record is None else record
        payload = self.payload if payload is None else payload
        public = self.public if public is None else public
        return self.lib.catkey_verify(record, len(record), public, role, allowed,
                                      required, kind, subject or self.subject,
                                      nonce or self.nonce, payload, len(payload))

    def test_sha256_known_answers(self):
        for data in (b"", b"abc", b"a" * 1000000):
            result = ctypes.create_string_buffer(32)
            self.assertEqual(self.lib.catkey_sha256(data, len(data), result), 0)
            self.assertEqual(result.raw, hashlib.sha256(data).digest())

    def test_ed25519_rfc8032_empty_message(self):
        public = bytes.fromhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        signature = bytes.fromhex("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555f"
                                  "b8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")
        self.assertEqual(self.lib.crypto_ed25519_check(signature, public, b"", 0), 0)

    def test_independent_signer_and_determinism(self):
        self.assertEqual(self.verify(), 0)
        self.assertEqual(self.record, catkey.build_record(self.key, self.payload, self.subject, 1))
        catkey.verify_record(self.record, self.public, self.payload, self.subject, 1)

    def test_all_modified_signed_body_bytes(self):
        for i in range(160):
            damaged = bytearray(self.record)
            damaged[i] ^= 1
            self.assertNotEqual(self.verify(bytes(damaged)), 0, f"accepted modified byte {i}")

    def test_all_modified_signature_bytes(self):
        for i in range(160, 224):
            damaged = bytearray(self.record)
            damaged[i] ^= 1
            self.assertNotEqual(self.verify(bytes(damaged)), 0)

    def test_size_boundary(self):
        for n in range(224):
            self.assertNotEqual(self.verify(self.record[:n]), 0)
        self.assertNotEqual(self.verify(self.record + b"\0"), 0)

    def test_image_and_length_tampering(self):
        self.assertEqual(self.verify(payload=self.payload + b"x"), -4)
        self.assertEqual(self.verify(payload=b"X" + self.payload[1:]), -4)

    def test_self_signed_unenrolled_key(self):
        other = catkey.raw_public(catkey.Ed25519PrivateKey.generate())
        self.assertEqual(self.verify(public=other), -2)

    def test_zero_key_is_no_enrollment(self):
        damaged = bytearray(self.record)
        damaged[96:128] = bytes(32)
        damaged[160:] = bytes(64)
        self.assertEqual(self.verify(record=bytes(damaged), public=bytes(32)), -3)
        with self.assertRaises(ValueError):
            catkey.verify_record(bytes(damaged), bytes(32), self.payload, self.subject, 1)

    def test_invalid_pointer_inputs(self):
        args = [self.record, len(self.record), self.public, 2, 3, 1, 1,
                self.subject, self.nonce, self.payload, len(self.payload)]
        for index in (0, 2, 7, 8, 9):
            bad = list(args)
            bad[index] = None
            self.assertEqual(self.lib.catkey_verify(*bad), -1)
        digest = ctypes.create_string_buffer(32)
        self.assertEqual(self.lib.catkey_sha256(None, 1, digest), -1)
        self.assertEqual(self.lib.catkey_sha256(b"abc", 3, None), -1)

    def test_image_subject_binding(self):
        self.assertEqual(self.verify(subject=catkey.subject_bytes("initrd.img")), -5)

    def test_token_permissions_identity_nonce(self):
        subject = hashlib.sha256(b"SIMULATED-device").digest()
        nonce = hashlib.sha256(b"test-only-challenge").digest()
        record = catkey.build_record(self.key, b"", subject, 1, kind=2, nonce=nonce)
        common = dict(record=record, payload=b"", kind=2, subject=subject, nonce=nonce)
        self.assertEqual(self.verify(**common), 0)
        self.assertEqual(self.verify(**common, required=4), -3)
        common["subject"] = bytes(32)
        self.assertEqual(self.verify(**common), -5)
        common["subject"], common["nonce"] = subject, bytes(32)
        self.assertEqual(self.verify(**common), -5)

    def test_role_comes_from_enrollment(self):
        self.assertEqual(self.verify(role=4), -3)
        self.assertEqual(self.verify(allowed=0), -3)

    def test_rollback_requires_trusted_storage(self):
        body = bytearray(self.record[:160])
        body[24] = 1
        record = bytes(body) + self.key.sign(bytes(body))
        self.assertEqual(self.verify(record), -3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
