#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Prepare genuine LGPL Syllable Thread, not a replacement C++ class."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import urlopen
ROOT=Path(__file__).resolve().parents[1]
REV="579e480a005321cc320e7e355e8dff398b689be8"
FILES={
    "system/sys/appserver/libsyllable/util/thread.cpp": "048bfc2c8faec1e900799e90c41a51ea9a5437bb23d415992544f25632a591e5",
    "system/sys/include/util/thread.h": "6e6660e056b6f4ef0b395b9691a9f6ddd66ffb17e9199d4c3b681a01d9173666",
    "system/sys/include/util/exceptions.h": "fc8c95376c9d555cd919aa37567f6b47b3b59b0fb6adbfc46a10bd4f529f0f92",
    "system/sys/include/atheos/time.h": "ad29a1c042d77b4ca3880acd2431fc512c09319566a5d642aa26d836e3c934fe",
}
OUT=ROOT/"build/syllable-thread"
def write_changed(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    if not path.exists() or path.read_bytes()!=data: path.write_bytes(data)
def main():
    records=[]; inputs={}
    for path,sha in FILES.items():
        target=OUT/"upstream"/path
        local=ROOT/"third_party/syllable"/path
        data=(target.read_bytes() if target.exists() else local.read_bytes() if local.exists() else
              urlopen(f"https://raw.githubusercontent.com/SyllableOS/Syllable/{REV}/{path}",timeout=30).read())
        data=data.replace(b"\r\n",b"\n")
        if hashlib.sha256(data).hexdigest()!=sha: raise RuntimeError(f"Syllable Thread source hash mismatch: {path}")
        write_changed(target,data); inputs[Path(path).name]=data
        if "/include/" in path: write_changed(OUT/"include"/path.split("/include/",1)[1],data)
        records.append({"path":path,"sha256":sha,"license":"LGPL-2.0-only"})
    scratch=OUT/"patch-work/thread.cpp"
    write_changed(scratch,inputs["thread.cpp"])
    patch=ROOT/"ports/syllable/patches/thread-rv32.patch"
    subprocess.run(["git","apply","--recount","--directory=build/syllable-thread/patch-work",str(patch)],cwd=ROOT,check=True)
    adapted=scratch.read_bytes(); write_changed(OUT/"thread.cpp",adapted)
    write_changed(OUT/"COPYING.LIB",(ROOT/"ports/syllable/COPYING.LIB").read_bytes())
    record={"commit":REV,"files":records,"patchSha256":hashlib.sha256(patch.read_bytes()).hexdigest(),
        "adaptedThreadSha256":hashlib.sha256(adapted).hexdigest(),"license":"LGPL-2.0-only",
        "sourceLicenseBasis":"thread.cpp has no per-file banner; matching public thread.h names Henrik Isaksson and LGPL version 2; original component COPYING.LIB retained",
        "scope":"genuine Thread source and headers; controller-owned native lifecycle, not full libsyllable/Looper/AppServer"}
    write_changed(OUT/"sources.json",(json.dumps(record,indent=2)+"\n").encode())
    print("PASS genuine LGPL Syllable Thread; native lifecycle patch, original public headers/notices preserved")
if __name__=="__main__": main()
