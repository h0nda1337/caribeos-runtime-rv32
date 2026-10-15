#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Select verified, unmodified GNU exception sources for a native TLS variant."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/native-cxx-context"
FILES = {
    "libstdc++-v3/libsupc++/eh_globals.cc": "edbdf6fcf2826ae7dd92d33048ce9f401233a6d62992c7a0e58e080995841526",
    "libstdc++-v3/libsupc++/eh_alloc.cc": "9d0c43102ec96faaab6b4339966c3587fcd3af75647c10d90fcec93e823ae877",
    "COPYING3": "8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903",
    "COPYING.RUNTIME": "9d6b43ce4d8de0c878bf16b54d8e7a10d9bd42b75178153e3af6a815bdc90f74",
}


def main():
    subprocess.run([sys.executable, str(ROOT / "scripts/prepare-cxx-deps.py")], cwd=ROOT, check=True)
    manifest = json.loads((ROOT / "build/cxx-source-manifest.json").read_text())
    records = []
    OUT.mkdir(parents=True, exist_ok=True)
    for path, expected in FILES.items():
        data = (ROOT / "third_party/gcc-15.1.0" / path).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest != expected or digest != manifest["files"][path]:
            raise RuntimeError("modified genuine GNU context input: " + path)
        target = OUT / Path(path).name
        if target.exists() and target.read_bytes() != data:
            raise RuntimeError("modified prepared GNU context input: " + path)
        target.write_bytes(data)
        records.append({"path": path, "sha256": digest})
    record = {"gnuVersion": "15.1.0", "archiveSha512": manifest["archiveSha512"], "files": records,
              "license": "GPL-3.0-or-later WITH GCC-exception-3.1; original notices intact",
              "sourcesModified": False, "scope": "genuine exception globals in ELF TLS; genuine allocation with supported zero emergency pool configuration; not full GNU threading"}
    (OUT / "sources.json").write_bytes((json.dumps(record, indent=2) + "\n").encode())
    print("PASS original GNU eh_globals/eh_alloc sources and complete license/exception notices")


if __name__ == "__main__":
    main()
