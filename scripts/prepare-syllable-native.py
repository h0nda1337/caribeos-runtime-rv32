#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pin genuine Syllable native IPC interfaces; preserve external notices."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/include/atheos/semaphore.h": "804102b669523edd9b18e1642f08199ee8e7ad42ad227420a3a41ea772d307f1",
    "system/sys/include/atheos/msgport.h": "d6f2dc81ec504e780debb17c69d22e0d3a0ca964e5cfcf04be0aea18b735cb9d",
    "system/sys/include/atheos/areas.h": "2d86daf76aae206e5ad9924e83663d9ba38c39796d368565c40664c19b8f4187",
    "system/sys/include/util/message.h": "4052416bbeba977470c890cddcc0c0e45a0d444ea1c3c1e4a20deb38beeb63b6",
    "system/sys/appserver/libsyllable/util/message.cpp": "b84c471b023ecaf17463a6a7dd5ffb376b49b43ea0ada0364c0d5a0d485faa38",
}
OUT = ROOT / "build/syllable-native"


def write_if_changed(path, data):
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main():
    records = []
    for path, expected in FILES.items():
        target = OUT / "upstream" / path
        data = target.read_bytes() if target.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f"Syllable native source hash mismatch: {path}")
        write_if_changed(target, data)
        compiled = path.endswith(("/msgport.h", "/areas.h", "/semaphore.h"))
        if compiled:
            write_if_changed(OUT / "include/atheos" / target.name, data)
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only",
                        "compiled": compiled})
    write_if_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    record = {"commit": REV, "files": records,
        "note": "Original port, area and counting semaphore headers are consumed by native XNU adapters; Message data core is built by its separate preparation script."}
    write_if_changed(OUT / "sources.json", (json.dumps(record, indent=2) + "\n").encode())
    print("PASS pinned Syllable native APIs and Message sources; LGPL notices unchanged")


if __name__ == "__main__":
    main()
