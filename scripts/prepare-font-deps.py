#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Verify unmodified official FreeType sources and publisher-pinned Vera fonts."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
VERSION = "2.15.0"
TAG = "VER-2-15-0"
COMMIT = "37515cf56ba3349656049edbed89ffc6f6466f2d"
TAG_OBJECT = "631ee12ce7693c9ba9ea33f0235da99218045420"
URL = "https://github.com/freetype/freetype.git"
SOURCE = ROOT / f"third_party/freetype-{VERSION}"
FONT_SHA256 = "3a84126ce11ef404d1453438e35450b9e0838220d262059e56cd8496ac6f5d15"
FONT_URL = "https://download.gnome.org/sources/ttf-bitstream-vera/1.10/ttf-bitstream-vera-1.10.tar.gz"
FONT_SOURCE = ROOT / "third_party/ttf-bitstream-vera-1.10"
MANIFEST = ROOT / "build/font-sources.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args, input=None):
    return subprocess.check_output(["git", "--no-replace-objects", "-C", str(SOURCE), *args], input=input)


def write_if_changed(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def prepare_freetype():
    if not SOURCE.exists():
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "-c", "core.autocrlf=false", "clone", "--depth", "1",
                        "--branch", TAG, URL, str(SOURCE)], check=True)
    if git("rev-parse", "HEAD").decode().strip() != COMMIT:
        raise RuntimeError("FreeType commit differs from the immutable pin")
    if git("rev-parse", TAG).decode().strip() != TAG_OBJECT:
        raise RuntimeError("FreeType release tag object differs from pin")
    if git("status", "--porcelain", "--untracked-files=all").strip():
        raise RuntimeError("refusing modified or untracked FreeType input files")
    files, excluded, records = {}, {}, []
    for record in git("ls-tree", "-rz", "HEAD").split(b"\0"):
        if not record:
            continue
        metadata, name = record.split(b"\t", 1)
        mode, kind, object_id = metadata.split()
        relative = name.decode("utf-8")
        if kind == b"commit":
            excluded[relative] = object_id.decode()
            continue
        if mode not in (b"100644", b"100755"):
            raise RuntimeError(f"unexpected FreeType file mode: {relative}")
        path = (SOURCE / relative).resolve()
        if not path.is_relative_to(SOURCE.resolve()) or not path.is_file():
            raise RuntimeError(f"missing/unsafe FreeType input: {relative}")
        records.append((relative, path, object_id))
    # One Git batch avoids hundreds of Windows process launches and repeated disk walks.
    output = io.BytesIO(git("cat-file", "--batch", input=b"\n".join(item[2] for item in records) + b"\n"))
    for relative, path, object_id in records:
        header = output.readline().strip().split()
        if len(header) != 3 or header[:2] != [object_id, b"blob"]:
            raise RuntimeError("invalid FreeType Git batch response")
        length = int(header[2]); blob = output.read(length)
        if len(blob) != length or output.read(1) != b"\n":
            raise RuntimeError("truncated FreeType Git blob")
        if hashlib.sha1(b"blob " + str(length).encode() + b"\0" + blob).hexdigest().encode() != object_id:
            raise RuntimeError("FreeType Git object content/hash mismatch")
        actual = path.read_bytes()
        if actual != blob and actual.replace(b"\r\n", b"\n") != blob:
            raise RuntimeError(f"FreeType content differs from pinned git blob: {relative}")
        files[relative] = digest(blob)
    if output.read():
        raise RuntimeError("extra FreeType Git batch data")
    return {"version": VERSION, "url": URL, "tag": TAG, "tagObject": TAG_OBJECT,
            "commit": COMMIT, "contentEncoding": "original git blobs; CRLF checkout allowed",
            "authentication": "official HTTPS mirror and immutable pins; no GPG verification claimed",
            "excludedSubmodules": excluded, "licenseChoice": "FTL with per-file exceptions preserved",
            "files": [{"path": path, "sha256": value} for path, value in sorted(files.items())]}


def prepare_fonts():
    archive = ROOT / "third_party/ttf-bitstream-vera-1.10.tar.gz"
    if not archive.exists():
        temporary = archive.with_suffix(".gz.part")
        with urlopen(FONT_URL, timeout=60) as response, temporary.open("wb") as output:
            for block in iter(lambda: response.read(1024 * 1024), b""):
                output.write(block)
        if digest(temporary.read_bytes()) != FONT_SHA256:
            raise RuntimeError("Vera archive differs from publisher checksum")
        temporary.replace(archive)
    if digest(archive.read_bytes()) != FONT_SHA256:
        raise RuntimeError("cached Vera archive checksum mismatch")
    files, pending = {}, []
    prefix = "ttf-bitstream-vera-1.10/"
    with tarfile.open(archive) as stream:
        for member in stream:
            if member.isdir():
                continue
            if not member.isfile() or not member.name.startswith(prefix):
                raise RuntimeError("unsafe Vera archive member")
            relative = member.name[len(prefix):]
            target = (FONT_SOURCE / relative).resolve()
            if not target.is_relative_to(FONT_SOURCE.resolve()):
                raise RuntimeError("unsafe Vera archive path")
            data = stream.extractfile(member).read()
            if target.exists() and target.read_bytes() != data:
                raise RuntimeError(f"refusing to overwrite modified Vera file: {relative}")
            pending.append((target, data))
            files[relative] = digest(data)
    for required in ("COPYRIGHT.TXT", "Vera.ttf", "VeraBd.ttf", "VeraMono.ttf"):
        if required not in files:
            raise RuntimeError(f"missing Vera distribution input: {required}")
    for target, data in pending:
        write_if_changed(target, data)
    return {"version": "1.10", "url": FONT_URL, "archiveSha256": FONT_SHA256,
            "publisherChecksums": FONT_URL + ".sha256sum",
            "files": [{"path": path, "sha256": value} for path, value in sorted(files.items())]}


def main():
    record = {"schema": 2, "freetype": prepare_freetype(), "vera": prepare_fonts(),
              "profile": "static RV32-musl; no external zlib/bzip2/png/harfbuzz/brotli/HVF; no dlg logging"}
    write_if_changed(MANIFEST, (json.dumps(record, indent=2, sort_keys=True) + "\n").encode())
    print(f"PASS FreeType {VERSION} {len(record['freetype']['files'])} pinned files; Vera publisher checksum")


if __name__ == "__main__":
    main()
