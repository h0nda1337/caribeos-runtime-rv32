#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Fetch pinned Syllable sources, preserve licenses, generate isolated port copies."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
BASE = f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/"
SERVER = "system/sys/appserver/appserver/server/"
HASHES = {
    "defaultdecorator.cpp": "a732e8186630dc491f9027b3e09c8ecd4f955ef7dbd1ea324416fa5a5219a1e6",
    "defaultdecorator.h": "fc82c6d3d6353d484ea0d02173103a843add0ba0f31650d58ea662c0fea99fa8",
    "windowdecorator.cpp": "82623c0d3e9443406fda6236ac0b90edb9f6c0908376dfc45eec43fa752eb1bb",
    "windowdecorator.h": "df3a83923a7c6f8b69ec8ea95d8f2ca1c95d9e17af53707e71cfd7ff89a51573",
}
OUT = ROOT / "build/syllable-port"
OUT.mkdir(parents=True, exist_ok=True)
records = []
for name, expected in HASHES.items():
    cached = ROOT / "third_party/syllable" / SERVER / name
    data = cached.read_bytes() if cached.exists() else urlopen(BASE + SERVER + name, timeout=30).read()
    data = data.replace(b"\r\n", b"\n")
    if hashlib.sha256(data).hexdigest() != expected:
        raise RuntimeError(f"Syllable source hash mismatch: {name}")
    (OUT / ("upstream-" + name)).write_bytes(data)
    text = data.decode()
    if name == "defaultdecorator.h":
        text = text.replace("#include <string>", '#include "adapter.h"')
        text = text.replace("std::string", "CaribeTitle")
    if name == "defaultdecorator.cpp":
        text = text.replace("std::max", "caribe_max")
    if name in ("defaultdecorator.h", "defaultdecorator.cpp"):
        text = ("/* CaribeOS modification notice: h0nda1337, 2026-10-12.\n"
                " * RV32 port: bounded CaribeTitle and caribe_max adapters.\n"
                " * SPDX-License-Identifier: LGPL-2.0-only\n"
                " * Original copyright and license notices follow unchanged.\n */\n" + text)
    (OUT / name).write_text(text, encoding="utf-8", newline="\n")
    records.append({"file": name, "upstreamSha256": expected,
                    "adaptedSha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                    "license": "LGPL-2.0-only"})
for name in ("layer.h", "gui/window.h", "gui/font.h", "gui/region.h", "atheos/types.h"):
    target = OUT / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('#include "adapter.h"\n', encoding="utf-8")
font_rev = "8e279d2d864e79128e96188a6b9526cfa3fbfef9"
cached = ROOT / "third_party/font8x8/font8x8_basic.h"
font = cached.read_bytes() if cached.exists() else urlopen(
    f"https://raw.githubusercontent.com/dhepper/font8x8/{font_rev}/font8x8_basic.h", timeout=30).read()
font = font.replace(b"\r\n", b"\n")
if hashlib.sha256(font).hexdigest() != "49d8df366296b203ca3211bc0672cf2a762135bf12710735b6292756b19dffd5":
    raise RuntimeError("font source hash mismatch")
(OUT / "font8x8_basic.h").write_bytes(font)
(OUT / "COPYING.LIB").write_bytes((ROOT / "ports/syllable/COPYING.LIB").read_bytes())
(OUT / "sources.json").write_text(json.dumps({"syllableCommit": REV, "files": records,
    "fontCommit": font_rev, "fontLicense": "public domain",
    "adaptations": ["bounded CaribeTitle replaces std::string", "caribe_max replaces std::max",
                    "Layer/geometry/font compatibility adapter; no AppServer IPC emulation"]}, indent=2) + "\n")
print("PASS pinned Syllable AppServer decorator sources and font; original notices preserved")
