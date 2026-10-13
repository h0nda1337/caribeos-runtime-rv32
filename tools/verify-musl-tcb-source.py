#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Read-only comparison with the pinned original musl archive; never extracts."""
import hashlib
import json
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.2.5"
ARCHIVE_SHA256 = "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4"
INPUTS = (
    "src/internal/pthread_impl.h", "src/internal/libc.h", "src/internal/syscall.h",
    "src/internal/futex.h", "src/internal/atomic.h", "src/include/features.h",
    "arch/riscv32/pthread_arch.h", "arch/riscv32/atomic_arch.h", "arch/riscv32/syscall_arch.h",
    "include/features.h", "include/pthread.h", "include/errno.h", "include/unistd.h",
    "src/env/__init_tls.c", "src/thread/pthread_self.c", "src/errno/__errno_location.c",
    "src/unistd/close.c", "src/thread/__syscall_cp.c", "COPYRIGHT",
)
INSTALLED = ("features.h", "pthread.h", "errno.h", "unistd.h")


def verify_sources(root=ROOT):
    archive = root / f"third_party/musl-{VERSION}.tar.gz"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise RuntimeError("musl archive differs from pinned official 1.2.5 source")
    records = []
    with tarfile.open(archive, "r:gz") as original:
        for path in INPUTS:
            member = original.getmember(f"musl-{VERSION}/{path}")
            if not member.isfile():
                raise RuntimeError("musl TCB source member must be a regular file")
            data = original.extractfile(member).read()
            if (root / f"third_party/musl-{VERSION}" / path).read_bytes() != data:
                raise RuntimeError(f"modified musl TCB source: {path}")
            if path.startswith("include/") and Path(path).name in INSTALLED:
                if (root / "build/musl-rv32-sysroot/usr/include" / Path(path).name).read_bytes() != data:
                    raise RuntimeError(f"installed musl header differs: {path}")
            records.append({"path": path, "sha256": hashlib.sha256(data).hexdigest()})
    return {"result": "PASS", "version": VERSION, "archiveSha256": ARCHIVE_SHA256,
            "license": "musl MIT-style COPYRIGHT unchanged", "inputs": records,
            "scope": "original TCB ABI headers and corresponding libc sources; not a new full libc rebuild"}


if __name__ == "__main__":
    print(json.dumps(verify_sources(), indent=2))
