#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Separate runtime adaptation of the complete original Syllable Looper."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/syllable-looper-runtime"


def main():
    subprocess.run([sys.executable, str(ROOT / "scripts/prepare-syllable-looper.py")], cwd=ROOT, check=True)
    base = ROOT / "build/syllable-looper"
    for target, source in (("looper.cpp", "looper.cpp"), ("handler.cpp", "handler.cpp"),
                           ("messagefilter.cpp", "src/messagefilter.cpp"), ("include/util/looper.h", "include/util/looper.h")):
        path = OUT / "patch-work" / target
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((base / source).read_bytes())
    patch = ROOT / "ports/syllable/patches/looper-runtime-rv32.patch"
    subprocess.run(["git", "apply", "--recount", "--directory=build/syllable-looper-runtime/patch-work", str(patch)], cwd=ROOT, check=True)
    records = {}
    for name in ("looper.cpp", "handler.cpp", "messagefilter.cpp", "include/util/looper.h"):
        data = (OUT / "patch-work" / name).read_bytes()
        target = OUT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        records[name] = hashlib.sha256(data).hexdigest()
    record = {"baseSourceRecordSha256": hashlib.sha256((base / "sources.json").read_bytes()).hexdigest(),
              "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(), "adaptedFiles": records,
              "license": "LGPL-2.0-only; original notices preserved", "scope": "original Looper native runtime adaptation, not a replacement event loop or complete AppServer"}
    (OUT / "sources.json").write_bytes((json.dumps(record, indent=2) + "\n").encode())
    print("PASS separate original Looper runtime inputs; original compilation checkpoint untouched")


if __name__ == "__main__":
    main()
