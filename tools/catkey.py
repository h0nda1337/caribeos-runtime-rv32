#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""CatKey v1 developer signer. Private PEM keys must live outside Git trees."""
import argparse
import hashlib
import os
import struct
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey

BODY = struct.Struct("<8s6I32s32s32s32s")
ROLES = {"firmware": 1, "development": 2, "maintenance": 3, "owner": 4, "attestation": 5}
PERMISSIONS = {"kernel": 1, "initrd": 2, "maintenance": 4, "firmware": 8}
ROLE_PERMISSIONS = {1: 8, 2: 3, 3: 4, 4: 7, 5: 0}


def outside_git(path):
    for parent in (path.resolve(), *path.resolve().parents):
        if (parent / ".git").exists():
            raise ValueError("private keys must be stored outside any Git worktree")


def subject_bytes(value, token=False):
    if token:
        out = bytes.fromhex(value)
        if len(out) != 32:
            raise ValueError("token subject must be a 32-byte identity hex string")
        return out
    out = value.encode("ascii")
    if not out or len(out) > 31 or b"\0" in out:
        raise ValueError("image subject must contain 1..31 ASCII bytes")
    return out.ljust(32, b"\0")


def raw_public(private):
    return private.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def build_record(private, payload, subject, permission, role=2, kind=1, nonce=bytes(32)):
    if permission == 0 or permission & ~ROLE_PERMISSIONS[role]:
        raise ValueError("permission is not authorized for this key role")
    body = BODY.pack(b"CATKEY1\0", 1, kind, role, permission, 0, len(payload),
                     subject, hashlib.sha256(payload).digest(), raw_public(private), nonce)
    return body + private.sign(body)


def verify_record(record, public, payload, subject, permission, role=2, kind=1, nonce=bytes(32)):
    if len(public) != 32 or public == bytes(32):
        raise ValueError("no public key enrolled")
    if len(record) != 224:
        raise ValueError("record size")
    magic, version, actual_kind, actual_role, perms, rollback, length, sub, digest, signer, challenge = BODY.unpack(record[:160])
    if magic != b"CATKEY1\0" or version != 1 or actual_kind != kind:
        raise ValueError("record format")
    if signer != public:
        raise ValueError("untrusted signer")
    Ed25519PublicKey.from_public_bytes(public).verify(record[160:], record[:160])
    if actual_role != role or not permission or not perms or perms & ~ROLE_PERMISSIONS[role] or perms & permission != permission or rollback:
        raise ValueError("permission or rollback policy")
    if sub != subject or challenge != nonce:
        raise ValueError("subject or challenge")
    if length != len(payload) or digest != hashlib.sha256(payload).digest() or (kind == 2 and payload):
        raise ValueError("payload digest")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    gen = commands.add_parser("keygen")
    gen.add_argument("--private", type=Path, required=True)
    gen.add_argument("--public", type=Path, required=True)
    enroll = commands.add_parser("enroll-header")
    enroll.add_argument("--public", type=Path, required=True)
    enroll.add_argument("--output", type=Path, required=True)
    for operation in ("sign-image", "sign-token", "verify-image", "verify-token"):
        sub = commands.add_parser(operation)
        sub.add_argument("--private" if operation.startswith("sign") else "--public", type=Path, required=True)
        sub.add_argument("--record", type=Path, required=True)
        sub.add_argument("--subject", required=True)
        sub.add_argument("--permission", choices=PERMISSIONS, required=True)
        sub.add_argument("--role", choices=ROLES, default="development")
        if operation.endswith("image"):
            sub.add_argument("--image", type=Path, required=True)
        else:
            sub.add_argument("--nonce", required=True)
    args = parser.parse_args()
    if args.command == "keygen":
        outside_git(args.private)
        private = Ed25519PrivateKey.generate()
        encoded = private.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                        serialization.NoEncryption())
        args.private.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(args.private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(encoded)
        with args.public.open("xb") as stream:
            stream.write(raw_public(private))
        print("Development Ed25519 keypair created outside Git; protect the private PEM with host ACLs.")
        return
    if args.command == "enroll-header":
        public = args.public.read_bytes()
        if len(public) != 32 or public == bytes(32):
            raise ValueError("expected a raw 32-byte Ed25519 public key")
        values = ",".join(f"0x{x:02x}" for x in public)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("/* Generated development public trust anchor; no private key. */\n"
                               f"#define CARIBE_DEV_PUBLIC_KEY {{{values}}}\n", encoding="ascii")
        return
    token = args.command.endswith("token")
    payload = b"" if token else args.image.read_bytes()
    subject = subject_bytes(args.subject, token)
    nonce = bytes.fromhex(args.nonce) if token else bytes(32)
    if len(nonce) != 32:
        raise ValueError("nonce must be a 32-byte random challenge")
    permission = PERMISSIONS[args.permission]
    role = ROLES[args.role]
    if args.command.startswith("sign"):
        outside_git(args.private)
        private = serialization.load_pem_private_key(args.private.read_bytes(), password=None)
        if not isinstance(private, Ed25519PrivateKey):
            raise ValueError("expected Ed25519 private key")
        args.record.write_bytes(build_record(private, payload, subject, permission, role, 2 if token else 1, nonce))
        print("Signed CatKey development record; identical inputs produce identical bytes.")
    else:
        verify_record(args.record.read_bytes(), args.public.read_bytes(), payload, subject,
                      permission, role, 2 if token else 1, nonce)
        print("CatKey verification PASS")


if __name__ == "__main__":
    main()
