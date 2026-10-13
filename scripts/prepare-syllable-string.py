#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pin real Syllable String inputs and apply a separately licensed port patch."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/appserver/libsyllable/util/string.cpp": "be51692bd68f9f917e8f4397177320295b8a258ccd66477a64885ce69cac501e",
    "system/sys/include/util/string.h": "a7931e6500afbb5f5bb8aea8cbf558500b0d7258aab354c650e08df89ffb9ab7",
    "system/sys/include/gui/font.h": "440148c1995bb22d0d9e043aa3375b4bec89c406052d85521345b98ea0229894",
}
OUT = ROOT / "build/syllable-string"


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    records = []
    sources = {}
    for path, expected in FILES.items():
        cached = ROOT / "third_party/syllable" / path
        data = cached.read_bytes() if cached.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f"Syllable String source hash mismatch: {path}")
        write_changed(OUT / "upstream" / path, data)
        sources[Path(path).name] = data
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only"})
    font = sources["font.h"].decode()
    helper = re.search(r"inline int utf8_char_length\( uint8 nFirstByte \)\n\{\n[^}]+\}", font)
    if helper is None:
        raise RuntimeError("Pinned font header no longer contains the expected UTF-8 helper")
    notice = ("/* CaribeOS modification notice: h0nda1337, 2026-10-13.\n"
              " * Isolate Syllable's existing UTF-8 byte-length helper; uint8 becomes unsigned char.\n"
              " * This is not a Font implementation or a Unicode validator.\n"
              " * SPDX-License-Identifier: LGPL-2.0-only\n */\n")
    original_license = font[:font.index("*/") + 2]
    narrow = (notice + original_license + "\n#pragma once\nnamespace os {\n" +
              helper.group().replace("uint8", "unsigned char") + "\n}\n")
    write_changed(OUT / "utf8_length.h", narrow.encode())
    write_changed(OUT / "include/util/string.h", sources["string.h"])
    patch = ROOT / "ports/syllable/patches/string-rv32.patch"
    patch_data = patch.read_bytes()
    # Apply to a scratch copy so unchanged outputs keep their timestamps.
    scratch = OUT / "patch-work"
    write_changed(scratch / "string.cpp", sources["string.cpp"])
    subprocess.run(["git", "apply", "--directory=build/syllable-string/patch-work", str(patch)],
                   cwd=ROOT, check=True)
    adapted = (scratch / "string.cpp").read_bytes()
    write_changed(OUT / "string.cpp", adapted)
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    manifest = {"commit": REV, "files": records,
                "patchSha256": hashlib.sha256(patch_data).hexdigest(),
                "adaptedStringSha256": hashlib.sha256(adapted).hexdigest(),
                "utf8HelperSha256": hashlib.sha256(narrow.encode()).hexdigest(),
                "license": "LGPL-2.0-only",
                "note": "Real String implementation; isolated existing UTF-8 helper, no Font/AppServer replacement."}
    write_changed(OUT / "sources.json", (json.dumps(manifest, indent=2) + "\n").encode())
    print("PASS genuine Syllable String sources, licensed RV32 patch and original notices")


if __name__ == "__main__":
    main()
