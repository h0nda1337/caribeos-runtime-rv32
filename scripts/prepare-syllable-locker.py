#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pin genuine LGPL Syllable Locker/thread interfaces and apply a narrow patch."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/include/util/locker.h": "55743b5932e41f4b2041359229185961bb8b2691c0cc2bec29c0d549c243a74e",
    "system/sys/include/atheos/threads.h": "4d0cf6a5ecf996208dd85d002ea25238acd12bc38057ac62758623931c2d9988",
}
OUT = ROOT / "build/syllable-locker"


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    records, sources = [], {}
    for path, expected in FILES.items():
        cached = ROOT / "third_party/syllable" / path
        data = cached.read_bytes() if cached.exists() else urlopen(
            f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read()
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f"Syllable Locker source hash mismatch: {path}")
        write_changed(OUT / "upstream" / path, data)
        sources[Path(path).name] = data
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only"})
    write_changed(OUT / "include/atheos/threads.h", sources["threads.h"])
    scratch = OUT / "patch-work/locker.h"
    write_changed(scratch, sources["locker.h"])
    patch = ROOT / "ports/syllable/patches/locker-rv32.patch"
    subprocess.run(["git", "apply", "--directory=build/syllable-locker/patch-work", str(patch)], cwd=ROOT, check=True)
    adapted = scratch.read_bytes()
    write_changed(OUT / "include/util/locker.h", adapted)
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    write_changed(OUT / "sources.json", (json.dumps({"commit": REV, "files": records,
        "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
        "adaptedLockerSha256": hashlib.sha256(adapted).hexdigest(), "license": "LGPL-2.0-only",
        "scope": "genuine Locker header and native thread interface, not Looper/AppServer or pthread"}, indent=2)+"\n").encode())
    print("PASS pinned genuine Syllable Locker; LGPL algorithm/notices preserved, not Looper/AppServer")


if __name__ == "__main__":
    main()
