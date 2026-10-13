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
    "system/sys/include/atheos/msgport.h": "d6f2dc81ec504e780debb17c69d22e0d3a0ca964e5cfcf04be0aea18b735cb9d",
    "system/sys/include/atheos/areas.h": "2d86daf76aae206e5ad9924e83663d9ba38c39796d368565c40664c19b8f4187",
    "system/sys/include/util/message.h": "4052416bbeba977470c890cddcc0c0e45a0d444ea1c3c1e4a20deb38beeb63b6",
    "system/sys/appserver/libsyllable/util/message.cpp": "b84c471b023ecaf17463a6a7dd5ffb376b49b43ea0ada0364c0d5a0d485faa38",
}
OUT = ROOT / "build/syllable-native"
records = []
for path, expected in FILES.items():
    target = OUT / "upstream" / path
    data = target.read_bytes() if target.exists() else urlopen(
        f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
    data = data.replace(b"\r\n", b"\n")
    if hashlib.sha256(data).hexdigest() != expected:
        raise RuntimeError(f"Syllable native source hash mismatch: {path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    if path.endswith("/msgport.h") or path.endswith("/areas.h"):
        include = OUT / "include/atheos" / target.name
        include.parent.mkdir(parents=True, exist_ok=True)
        include.write_bytes(data)
    records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only",
                    "compiled": path.endswith("/msgport.h")})
(OUT / "COPYING.LIB").write_bytes((ROOT / "ports/syllable/COPYING.LIB").read_bytes())
(OUT / "sources.json").write_text(json.dumps({"commit": REV, "files": records,
    "note": "Only msgport.h is consumed by this first native IPC adapter; Message is audited, not yet compiled."}, indent=2) + "\n")
print("PASS pinned Syllable native APIs and Message sources; LGPL notices unchanged")
