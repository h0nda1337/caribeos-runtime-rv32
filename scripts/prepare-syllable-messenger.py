#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Separate genuine Messenger/Message delivery variant; no replacement classes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
OUT = ROOT / "build/syllable-messenger"
FILES = {
    "system/sys/appserver/libsyllable/util/messenger.cpp": "1a84e4af331cc16674f2458a83005fb5419929b584ccaa3b01e12e9a88087b18",
    "system/sys/include/util/messenger.h": "5906a53ddf672497748ed66c10870698bef585da5af0331b79827e43001c9425",
}


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    subprocess.run([sys.executable, str(ROOT / "scripts/prepare-syllable-message.py")], cwd=ROOT, check=True)
    base = ROOT / "build/syllable-message"
    records = []
    for relative, expected in FILES.items():
        cached = OUT / "upstream" / relative
        data = cached.read_bytes() if cached.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{relative}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError("Messenger original source hash mismatch: " + relative)
        write_changed(cached, data)
        name = "include/util/messenger.h" if relative.endswith(".h") else "messenger.cpp"
        write_changed(OUT / "patch-work" / name, data)
        records.append({"path": relative, "sha256": expected, "license": "LGPL-2.0-only"})
    for name in ("message.cpp", "include/util/message.h"):
        write_changed(OUT / "patch-work" / name, (base / name).read_bytes())
    patch = ROOT / "ports/syllable/patches/messenger-runtime-rv32.patch"
    subprocess.run(["git", "apply", "--recount", "--directory=build/syllable-messenger/patch-work", str(patch)], cwd=ROOT, check=True)
    adapted = {}
    for name in ("include/util/flattenable.h", "include/util/typecodes.h"):
        write_changed(OUT / "patch-work" / name, (base / name).read_bytes())
    for name in ("messenger.cpp", "message.cpp", "include/util/messenger.h", "include/util/message.h", "include/util/flattenable.h", "include/util/typecodes.h"):
        data = (OUT / "patch-work" / name).read_bytes()
        write_changed(OUT / name, data)
        adapted[name] = hashlib.sha256(data).hexdigest()
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    record = {"commit": REV, "files": records, "baseMessageSourceSha256": hashlib.sha256((base / "sources.json").read_bytes()).hexdigest(),
              "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(), "adaptedSha256": adapted,
              "license": "LGPL-2.0-only; complete original notices preserved", "maxWireBytes": 8192,
              "profile": "CARIBE_SYLLABLE_MESSAGE_CORE + CARIBE_SYLLABLE_MESSAGE_DELIVERY",
              "excluded": ["Variant methods", "complete AppServer/Desktop"],
              "scope": "Original Messenger and Message reply/return-address methods; default data-core library unchanged"}
    write_changed(OUT / "sources.json", (json.dumps(record, indent=2) + "\n").encode())
    print("PASS pinned original Messenger and separate Message delivery adaptation; LGPL notices preserved")


if __name__ == "__main__":
    main()
