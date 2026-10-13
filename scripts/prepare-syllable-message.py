#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pin and build the genuine Syllable Message data core; no Looper stubs."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/appserver/libsyllable/util/message.cpp": "b84c471b023ecaf17463a6a7dd5ffb376b49b43ea0ada0364c0d5a0d485faa38",
    "system/sys/include/util/message.h": "4052416bbeba977470c890cddcc0c0e45a0d444ea1c3c1e4a20deb38beeb63b6",
    "system/sys/include/util/flattenable.h": "1e7008ac81d8a87b780a5b2d7ad189e11146ba702d990c985e06091bbfca7cce",
    "system/sys/include/util/typecodes.h": "34ef0392dfe16f31d636b64f616585cba5baa4e76f3b8dcc92bb11d7d38e64d2",
    "system/sys/include/gui/point.h": "d169476f71eed6a11ef782a6c37237a0cf786c5e63461f4021a8943c3a8d5b18",
    "system/sys/include/gui/rect.h": "463772a0b43fd34e587b7b6fba297aa2933da576f95c189e045927270a248578",
    "system/sys/include/gui/gfxtypes.h": "d0a3badf8e2cdf0943c28653ec9bb689a7583fbff5c93960338b242e73c24f14",
}
OUT = ROOT / "build/syllable-message"


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    records = []
    relatives = []
    scratch = OUT / "patch-work"
    for path, expected in FILES.items():
        cached = ROOT / "third_party/syllable" / path
        data = cached.read_bytes() if cached.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f"Syllable Message source hash mismatch: {path}")
        write_changed(OUT / "upstream" / path, data)
        relative = "message.cpp" if path.endswith(".cpp") else "include/" + path.split("/include/", 1)[1]
        relatives.append(relative)
        write_changed(scratch / relative, data)
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only"})
    patch = ROOT / "ports/syllable/patches/message-rv32.patch"
    subprocess.run(["git", "apply", "--directory=build/syllable-message/patch-work", str(patch)], cwd=ROOT, check=True)
    adapted = {}
    for relative in relatives:
        data = (scratch / relative).read_bytes()
        write_changed(OUT / relative, data)
        adapted[relative] = hashlib.sha256(data).hexdigest()
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    manifest = {"commit": REV, "files": records, "adaptedSha256": adapted,
                "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
                "compiledProfile": "CARIBE_SYLLABLE_MESSAGE_CORE", "maxWireBytes": 8192,
                "maxNestedDepth": 16, "license": "LGPL-2.0-only",
                "excluded": ["Looper/Handler delivery", "Messenger/ReturnAddress", "Variant methods"],
                "legacyUnflatten": "Trusted complete buffers only; never use for untrusted transport"}
    write_changed(OUT / "sources.json", (json.dumps(manifest, indent=2) + "\n").encode())
    print("PASS pinned genuine Syllable Message data core; bounded LGPL patch, no Looper stubs")


if __name__ == "__main__":
    main()
