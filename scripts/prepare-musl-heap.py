#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Separate, verified musl build inputs; no edits to the default musl tree."""
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/musl-heap-source"
ARCHIVE_SHA = "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4"
ARCH_PATH = "arch/riscv32/syscall_arch.h"
ARCH_SHA = "56f4c9037b90d4b428662c404b60da8490ed186b9183130bc4ea00e027071f8d"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    archive = ROOT / "third_party/musl-1.2.5.tar.gz"
    if sha(archive.read_bytes()) != ARCHIVE_SHA:
        raise RuntimeError("musl archive differs from official pinned 1.2.5 input")
    source = OUT / "musl-1.2.5"
    patch = ROOT / "ports/musl/patches/native-heap-rv32.patch"
    previous = json.loads((OUT / "sources.json").read_text()) if (OUT / "sources.json").exists() else {}
    reapply = True
    records = []
    with tarfile.open(archive, "r:gz") as upstream:
        if not source.exists():
            OUT.mkdir(parents=True, exist_ok=True)
            upstream.extractall(OUT, filter="data")
        for member in upstream.getmembers():
            if not member.isfile():
                continue
            path = member.name.removeprefix("musl-1.2.5/")
            if path == member.name:
                raise RuntimeError("unexpected musl archive root")
            data = upstream.extractfile(member).read()
            actual = (source / path).read_bytes()
            if path == ARCH_PATH:
                if sha(data) != ARCH_SHA:
                    raise RuntimeError("modified original musl RV32 syscall header")
                if actual != data and sha(actual) != previous.get("adaptedArchSha256"):
                    raise RuntimeError("unrecognized modification to prepared musl architecture header")
                reapply = actual == data or sha(patch.read_bytes()) != previous.get("patchSha256")
                if reapply:
                    write_changed(source / path, data)
            elif actual != data:
                raise RuntimeError(f"modified original allocator/libc input: {path}")
            records.append({"path": path, "sha256": sha(data)})
    if reapply:
        subprocess.run(["git", "apply", "--recount", "--directory=build/musl-heap-source/musl-1.2.5", str(patch)], cwd=ROOT, check=True)
    record = {"version": "1.2.5", "archiveSha256": ARCHIVE_SHA,
              "originalArchSha256": ARCH_SHA, "adaptedArchSha256": sha((source / ARCH_PATH).read_bytes()),
              "patchSha256": sha(patch.read_bytes()), "originalInputs": records,
              "license": "MIT; complete original musl COPYRIGHT unchanged",
              "scope": "genuine mallocng/futex locks; only RV32 VM syscall routing changed; not pthread or threaded GNU runtime"}
    write_changed(OUT / "sources.json", (json.dumps(record, indent=2)+"\n").encode())
    print(f"PASS {len(records)} original musl inputs, unmodified mallocng/locks/COPYRIGHT and separate MIT routing patch")


if __name__ == "__main__":
    main()
