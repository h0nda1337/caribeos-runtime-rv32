#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pinned genuine Variant and separately enabled Message variant methods."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/syllable-variant"
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/appserver/libsyllable/util/variant.cpp": "f85f3591915e8b901eb7ae9da1d2c7a095f6a35cb7861bde539137c94b6f14da",
    "system/sys/include/util/variant.h": "a9c396b0edb90dc93ec20530969ae759b64e5768bafa17888d30c453eebb8bc2",
}


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--original-only", action="store_true", help="Prepare pinned inputs only, not a buildable adapted record")
    args = parser.parse_args()
    subprocess.run([sys.executable, str(ROOT / "scripts/prepare-syllable-messenger.py")], cwd=ROOT, check=True)
    records = []
    names = []
    for path, expected in FILES.items():
        cached = OUT / "upstream" / path
        data = cached.read_bytes() if cached.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError("Variant original source hash mismatch: " + path)
        write_changed(cached, data)
        name = "include/util/variant.h" if path.endswith(".h") else "variant.cpp"
        names.append(name)
        write_changed(OUT / "baseline" / name, data)
        write_changed(OUT / "patch-work" / name, data)
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only"})
    base = ROOT / "build/syllable-messenger"
    for name in ("message.cpp", "include/util/message.h", "include/util/messenger.h", "include/util/flattenable.h", "include/util/typecodes.h"):
        names.append(name)
        data = (base / name).read_bytes()
        write_changed(OUT / "baseline" / name, data)
        write_changed(OUT / "patch-work" / name, data)
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    if args.original_only:
        print("PASS pinned original Variant/baseline inputs only; not adapted, linked or runtime proof")
        return
    patch = ROOT / "ports/syllable/patches/variant-runtime-rv32.patch"
    subprocess.run(["git", "apply", "--directory=build/syllable-variant/patch-work", str(patch)], cwd=ROOT, check=True)
    adapted = {}
    for name in names:
        data = (OUT / "patch-work" / name).read_bytes()
        write_changed(OUT / name, data)
        adapted[name] = hashlib.sha256(data).hexdigest()
    record = {"commit": REV, "files": records, "baseMessengerSourceSha256": hashlib.sha256((base / "sources.json").read_bytes()).hexdigest(),
              "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(), "adaptedSha256": adapted,
              "license": "LGPL-2.0-only; original public methods and notices preserved",
              "maxWireBytes": 8192, "maxCombinedMessageVariantDepth": 16,
              "profile": "CARIBE_SYLLABLE_MESSAGE_VARIANT + existing delivery/core profile",
              "scope": "Original Variant and Message typed values for genuine GUI controls; not Application/AppServer/Desktop"}
    write_changed(OUT / "sources.json", (json.dumps(record, indent=2) + "\n").encode())
    print("PASS separate original Variant/Message typed-value inputs; original notices preserved")


if __name__ == "__main__":
    main()
