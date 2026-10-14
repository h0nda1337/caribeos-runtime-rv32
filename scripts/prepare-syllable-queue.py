#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Prepare the original LGPL MessageQueue; no substitute class or Looper stubs."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
FILES = {
    "system/sys/appserver/libsyllable/util/messagequeue.cpp": "c17acce2749301f9821477972a9761f37603e56997a12f076fc75cd11dedd562",
    "system/sys/include/util/messagequeue.h": "4b21fba59c97129984aab7668b68efd1736b9536ebb2a7ba8f1caea898af3c33",
}
OUT = ROOT / "build/syllable-queue"


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    records = []
    for path, sha in FILES.items():
        target = OUT / "upstream" / path
        local = ROOT / "third_party/syllable" / path
        data = (target.read_bytes() if target.exists() else local.read_bytes() if local.exists() else
                urlopen(f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read())
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != sha:
            raise RuntimeError(f"MessageQueue source hash mismatch: {path}")
        write_changed(target, data)
        if "/include/" in path:
            write_changed(OUT / "include" / path.split("/include/", 1)[1], data)
        else:
            write_changed(OUT / "patch-work/messagequeue.cpp", data)
        records.append({"path": path, "sha256": sha, "license": "LGPL-2.0-only"})
    patch = ROOT / "ports/syllable/patches/messagequeue-rv32.patch"
    subprocess.run(["git", "apply", "--recount", "--directory=build/syllable-queue/patch-work", str(patch)],
                   cwd=ROOT, check=True)
    adapted = (OUT / "patch-work/messagequeue.cpp").read_bytes()
    write_changed(OUT / "messagequeue.cpp", adapted)
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    record = {"commit": REV, "files": records, "patchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
              "adaptedQueueSha256": hashlib.sha256(adapted).hexdigest(), "license": "LGPL-2.0-only",
              "scope": "genuine intrusive MessageQueue and original public header; not Looper/AppServer or threaded libc"}
    write_changed(OUT / "sources.json", (json.dumps(record, indent=2) + "\n").encode())
    print("PASS genuine LGPL MessageQueue; original header/notices and auditable tail/lifecycle patch retained")


if __name__ == "__main__":
    main()
