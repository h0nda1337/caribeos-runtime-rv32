#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Pin complete genuine event-dispatch sources before native integration."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
REV = "579e480a005321cc320e7e355e8dff398b689be8"
OUT = ROOT / "build/syllable-looper"
FILES = {
    "system/sys/appserver/libsyllable/util/handler.cpp": "64d2c358bc4b2f2bda4577cb369c4526f7761cba265bc4d07de1fc3b587086db",
    "system/sys/appserver/libsyllable/util/looper.cpp": "b6a820e5c8b27e7ac5f1521e8fd3c8795077467defd315a43fea6780d6f31ec2",
    "system/sys/appserver/libsyllable/util/messagefilter.cpp": "4c18b9eb7b16b2f88cbf2d648da4703462ef31651e587b92832e6025dc4d7997",
    "system/sys/include/util/handler.h": "301ba2adf69f16594cb354830763af18f9fdcef2b0e6978c1f1eadd1c3712b5d",
    "system/sys/include/util/looper.h": "24179b1f0f4af4d556f48999c3076428fb3e1d560648b51bec3905e429b9d2a5",
    "system/sys/include/util/messagefilter.h": "21b5eac6118c88d5cb10ef2dd8df532b1c7fdd58a8ce64e8395589ff6b75ab48",
    "system/sys/include/gui/guidefines.h": "e9545385b311cf9a473a51eea44170d1367e51826c0d7b9ea737886609d89c57",
    "system/sys/include/atheos/filesystem.h": "c2a24439f475ea12f7195bd0f08652fe7f515993faa5d1114fa84ec407a6018e",
    "system/sys/include/atheos/fs_attribs.h": "e56af453d0552dc92ca77690e3658b2671d28c52c38747d6a09501884dd5c881",
    "system/sys/include/atheos/messages.h": "18b6d2bae97aecae214ce20d4dc8f97da42d59a23fa42f146c9dcd20089cda51",
}


def write_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def main():
    records = []
    for path, expected in FILES.items():
        cached = OUT / "upstream" / path
        local = ROOT / "third_party/syllable" / path
        data = (cached.read_bytes() if cached.exists() else local.read_bytes() if local.exists() else
                urlopen(f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}", timeout=30).read())
        data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError(f"Looper dependency source hash mismatch: {path}")
        write_changed(cached, data)
        prepared = (OUT / "include" / path.split("/include/", 1)[1] if "/include/" in path
                    else OUT / "src" / Path(path).name)
        if prepared.exists() and prepared.read_bytes() != data:
            raise RuntimeError(f"unreviewed change to original prepared Looper dependency: {path}")
        write_changed(prepared, data)
        records.append({"path": path, "sha256": expected, "license": "LGPL-2.0-only"})
    write_changed(OUT / "COPYING.LIB", (ROOT / "ports/syllable/COPYING.LIB").read_bytes())
    patch = ROOT / "ports/syllable/patches/handler-rv32.patch"
    write_changed(OUT / "patch-work/handler.cpp", (OUT / "src/handler.cpp").read_bytes())
    subprocess.run(["git", "apply", "--recount", "--directory=build/syllable-looper/patch-work", str(patch)],
                   cwd=ROOT, check=True)
    adapted = (OUT / "patch-work/handler.cpp").read_bytes()
    write_changed(OUT / "handler.cpp", adapted)
    platform_patch = ROOT / "ports/syllable/patches/looper-platform-rv32.patch"
    write_changed(OUT / "patch-work/looper.cpp", (OUT / "src/looper.cpp").read_bytes())
    write_changed(OUT / "patch-work/include/atheos/filesystem.h", (OUT / "include/atheos/filesystem.h").read_bytes())
    subprocess.run(["git", "apply", "--recount", "--directory=build/syllable-looper/patch-work", str(platform_patch)],
                   cwd=ROOT, check=True)
    adapted_looper = (OUT / "patch-work/looper.cpp").read_bytes()
    adapted_fs = (OUT / "patch-work/include/atheos/filesystem.h").read_bytes()
    write_changed(OUT / "looper.cpp", adapted_looper)
    write_changed(OUT / "native/include/atheos/filesystem.h", adapted_fs)
    write_changed(OUT / "native/include/syllable/messages.h", (OUT / "include/atheos/messages.h").read_bytes())
    record = {"commit": REV, "files": records, "license": "LGPL-2.0-only",
              "originalInputsUnchanged": True, "runtimeVerified": False,
              "handlerPatchSha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
              "adaptedHandlerSha256": hashlib.sha256(adapted).hexdigest(),
              "platformPatchSha256": hashlib.sha256(platform_patch.read_bytes()).hexdigest(),
              "adaptedLooperSha256": hashlib.sha256(adapted_looper).hexdigest(),
              "adaptedFilesystemHeaderSha256": hashlib.sha256(adapted_fs).hexdigest(),
              "nodeMonitorImplemented": False,
              "scope": "complete original event-dispatch inputs and native compilation adaptations; not linked or running Looper/AppServer"}
    write_changed(OUT / "sources.json", (json.dumps(record, indent=2)+"\n").encode())
    print(f"PASS {len(records)} pinned original event-dispatch inputs and LGPL notices; source/compilation preparation only")


if __name__ == "__main__":
    main()
