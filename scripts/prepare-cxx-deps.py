#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Fetch matching GNU runtime sources, verifying the publisher's pinned SHA-512."""
import hashlib
import json
from pathlib import Path
import tarfile
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
VERSION = "15.1.0"
SHA512 = "ddd35ca6c653dffa88f7c7ef9ee4cd806e156e0f3b30f4d63e75a8363361285cd566ee73127734cde6a934611de815bee3e32e24bfd2e0ab9f7ff35c929821c1"
URL = f"https://gcc.gnu.org/pub/gcc/releases/gcc-{VERSION}/gcc-{VERSION}.tar.xz"
ARCHIVE = ROOT / f"third_party/gcc-{VERSION}.tar.xz"
SOURCE = ROOT / f"third_party/gcc-{VERSION}"
MANIFEST = ROOT / "build/cxx-source-manifest.json"

def digest(path, algorithm="sha256"):
    result = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()

def needed(relative):
    if "/" not in relative:
        return True
    if relative in ("gcc/BASE-VER", "gcc/DATESTAMP", "gcc/DEV-PHASE", "contrib/relpath.sh"):
        return True
    top = relative.split("/", 1)[0]
    if top not in ("libstdc++-v3", "libgcc", "include", "config", "libiberty"):
        return False
    if relative.startswith("libstdc++-v3/testsuite/"):
        return relative.endswith("/Makefile.in")
    return True

def main():
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    if not ARCHIVE.exists():
        temporary = ARCHIVE.with_suffix(".xz.part")
        print(f"Downloading GNU GCC {VERSION} runtime sources to {ARCHIVE.parent}", flush=True)
        with urlopen(URL, timeout=60) as response, temporary.open("wb") as output:
            for block in iter(lambda: response.read(1024 * 1024), b""):
                output.write(block)
        if digest(temporary, "sha512") != SHA512:
            raise RuntimeError("GNU GCC source archive SHA-512 mismatch")
        temporary.replace(ARCHIVE)
    if digest(ARCHIVE, "sha512") != SHA512:
        raise RuntimeError("cached GNU GCC archive differs from publisher checksum")
    if MANIFEST.exists():
        record = json.loads(MANIFEST.read_text())
        if record.get("archiveSha512") != SHA512:
            raise RuntimeError("C++ source manifest pin mismatch")
        for relative, expected in record["files"].items():
            target = (SOURCE / relative).resolve()
            if not target.is_relative_to(SOURCE.resolve()):
                raise RuntimeError("unsafe cached GNU input path")
            if not target.is_file() or digest(target) != expected:
                raise RuntimeError(f"prepared GNU input changed or missing: {relative}")
        if record.get("selectionRevision") == 3:
            print(f"PASS verified {len(record['files'])} unchanged GNU runtime inputs", flush=True)
            return
    files = {}
    prefix = f"gcc-{VERSION}/"
    with tarfile.open(ARCHIVE) as archive:
        for member in archive:
            if not member.name.startswith(prefix) or not member.isfile():
                continue
            relative = member.name[len(prefix):]
            if not needed(relative):
                continue
            target = (SOURCE / relative).resolve()
            if not target.is_relative_to(SOURCE.resolve()):
                raise RuntimeError("unsafe GNU archive path")
            data = archive.extractfile(member).read()
            if target.exists() and target.read_bytes() != data:
                raise RuntimeError(f"refusing to overwrite modified third-party source: {relative}")
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                target.write_bytes(data)
            if member.mode & 0o111:
                target.chmod(target.stat().st_mode | 0o111)
            files[relative] = hashlib.sha256(data).hexdigest()
    MANIFEST.write_text(json.dumps({"version": VERSION, "selectionRevision": 3, "url": URL, "archiveSha512": SHA512,
        "publisherChecksums": "https://gcc.gnu.org/pub/gcc/releases/gcc-15.1.0/sha512.sum",
        "selection": "GNU runtime/build inputs only; complete source archive retained; no compiler rebuild",
        "files": files}, indent=2) + "\n")
    print(f"PASS pinned and extracted {len(files)} GNU runtime inputs; licenses unchanged", flush=True)

if __name__ == "__main__":
    main()
