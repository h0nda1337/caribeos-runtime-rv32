#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Compile the actual AppServer inventory, preserving unfinished work explicitly."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT / "build/syllable-upstream-audit"
OUT = ROOT / "build/syllable-server-frontier"
PREFIX = "system/sys/appserver/appserver/server/"
REV = "579e480a005321cc320e7e355e8dff398b689be8"


def client_helpers():
    spec = importlib.util.spec_from_file_location("server_client_source_guards", ROOT / "scripts/audit-syllable-client-compile.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def inventory(data):
    logical = data.decode().replace("\r\n", "\n").replace("\\\n", " ")
    match = re.search(r"(?m)^OBJS\s*=\s*(.*)$", logical)
    if match is None:
        raise RuntimeError("missing original AppServer object inventory")
    names = match[1].split()
    if len(names) != 27 or len(set(names)) != 27 or not all(re.fullmatch(r"[a-z0-9_]+\.o", name) for name in names):
        raise RuntimeError("unexpected original AppServer inventory; review instead of silently skipping units")
    return [name[:-2] for name in names]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--retain-evidence", action="store_true", help="Retain truthful partial compiler proof, never server runtime success")
    args = parser.parse_args()
    helpers = client_helpers()
    if subprocess.check_output(["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True).strip() != REV:
        raise RuntimeError("wrong pinned upstream server revision")
    raw = subprocess.check_output(["git", "-C", str(REPO), "ls-tree", "-rz", REV, "system/sys/include", PREFIX])
    objects = {}
    for entry in raw.split(b"\0"):
        if entry:
            metadata, path = entry.split(b"\t", 1)
            mode, kind, digest = metadata.split()
            if mode == b"100644" and kind == b"blob":
                objects[path.decode()] = digest.decode()
    OUT.mkdir(parents=True, exist_ok=True)
    sources = []

    def original(name, target):
        if name not in objects:
            raise RuntimeError("unlisted original server input: " + name)
        cached = ROOT / "third_party/syllable" / name
        data = cached.read_bytes() if cached.exists() else subprocess.check_output(["git", "-C", str(REPO), "show", f"{REV}:{name}"])
        helpers.verify_header(data, objects[name], name)
        data = data.replace(b"\r\n", b"\n")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        sources.append({"path": name, "upstreamGitBlob": objects[name], "normalizedSha256": hashlib.sha256(data).hexdigest()})
        return data

    makefile = original(PREFIX + "Makefile", OUT / "original.Makefile")
    units = inventory(makefile)
    for name in objects:
        if name.startswith(PREFIX) and name.endswith(".h") and "/" not in name[len(PREFIX):]:
            original(name, OUT / name[len(PREFIX):])
    for path in sorted((ROOT / "third_party/syllable/system/sys/include").rglob("*")):
        if path.is_file():
            name = path.relative_to(ROOT / "third_party/syllable").as_posix()
            helpers.verify_header(path.read_bytes(), objects.get(name), name)
            sources.append({"path": name, "upstreamGitBlob": objects[name], "normalizedSha256": hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()})
    for path in sorted((OUT / "include").rglob("*")):
        if path.is_file():
            name = "system/sys/include/" + path.relative_to(OUT / "include").as_posix()
            helpers.verify_header(path.read_bytes(), objects.get(name), name)

    workspace = ROOT.parent.parent
    env = os.environ.copy()
    env["CARIBE_MUSL_SYSROOT"] = str(ROOT / "build/musl-heap-rv32-sysroot")
    env["TEMP"] = env["TMP"] = env["TMPDIR"] = str(workspace / "tmp")
    env["PATH"] = os.pathsep.join([str(workspace / "msys64/ucrt64/bin"), str(workspace / "msys64/usr/bin"), env.get("PATH", "")])
    cxx = ROOT / "build/cxx-rv32-sysroot/usr/include/c++/15.1.0"
    includes = [OUT, OUT / "include", ROOT / "ports/syllable/server-native", cxx, cxx / "riscv32-unknown-linux-musl", ROOT / "build/syllable-variant/include",
                ROOT / "ports/syllable/native", ROOT / "build/syllable-looper/native/include", ROOT / "build/syllable-looper/include"]
    includes += [ROOT / "build" / name / "include" for name in ("syllable-looper-runtime", "syllable-queue", "syllable-thread", "syllable-locker", "syllable-string", "syllable-native")]
    includes += [ROOT / "build/freetype-rv32-sysroot/usr/include/freetype2", ROOT / "third_party/syllable/system/sys/include"]
    flags = ["-O2", "-std=gnu++17", "-D_GNU_SOURCE", "-D__NO_SCREENSHOT_SUPPORT__=1", "-ffunction-sections", "-fdata-sections",
             "-msmall-data-limit=0", "-Wall", "-Wextra", "-DCARIBE_SYLLABLE_MESSAGE_CORE", "-DCARIBE_SYLLABLE_MESSAGE_DELIVERY",
             "-DCARIBE_SYLLABLE_MESSAGE_VARIANT", "-include", "third_party/syllable/system/sys/include/atheos/kdebug.h",
             "-include", "string.h", "-include", "limits.h", "-include", "ports/syllable/native/atheos/types.h",
             *["-I" + str(path) for path in includes]]
    rows = []
    for unit in units:
        source = OUT / (unit + ".cpp")
        original(PREFIX + unit + ".cpp", source)
        target = OUT / (unit + ".o")
        command = [str(workspace / "msys64/usr/bin/bash.exe"), "scripts/riscv32-musl-cxx.sh", *flags, "-c", str(source), "-o", str(target)]
        for attempt in range(16):
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            missing = re.search(rb"fatal error: ([A-Za-z0-9_./-]+): No such file or directory", result.stdout)
            if not missing:
                break
            name = "system/sys/include/" + missing[1].decode()
            private = PREFIX + missing[1].decode()
            if private in objects:
                original(private, OUT / missing[1].decode())
            elif name in objects:
                original(name, OUT / "include" / missing[1].decode())
            else:
                break
        log = OUT / (unit + "-compile.txt")
        log.write_bytes(result.stdout)
        errors = [line for line in result.stdout.decode(errors="replace").splitlines() if "error:" in line.lower()][:5]
        row = {"unit": unit, "exitCode": result.returncode, "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
               "firstCompilerErrors": errors, "command": command, "compilerLogSha256": hashlib.sha256(result.stdout).hexdigest()}
        if result.returncode == 0:
            elf = target.read_bytes()
            if elf[:7] != b"\x7fELF\x01\x01\x01" or elf[18:20] != b"\xf3\x00" or int.from_bytes(elf[36:40], "little") & 6:
                raise RuntimeError("server object is not RV32 ELF/soft-float")
            symbols = subprocess.check_output([str(workspace / "msys64/ucrt64/bin/riscv64-unknown-elf-nm.exe"), "-C", "-u", str(target)])
            (OUT / (unit + "-unresolved.txt")).write_bytes(symbols)
            row.update(objectSha256=hashlib.sha256(elf).hexdigest(), unresolvedSha256=hashlib.sha256(symbols).hexdigest())
        rows.append(row)
        print(unit, "COMPILED" if result.returncode == 0 else "UNPORTED", *errors, sep="\n  ", flush=True)
    complete = all(row["exitCode"] == 0 for row in rows)
    record = {"result": "COMPILED_NOT_LINKED" if complete else "INCOMPLETE", "upstreamRevision": REV, "inventory": units,
              "auditorSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "platformHeaders": [{"path": "ports/syllable/server-native/atheos/kernel.h",
                                   "sha256": hashlib.sha256((ROOT / "ports/syllable/server-native/atheos/kernel.h").read_bytes()).hexdigest()}],
              "sources": sources, "units": rows, "sourcesModified": False, "linked": False, "runtimeVerified": False,
              "displayBackendPorted": False, "appServerRunning": False,
              "scope": "Complete original AppServer compilation frontier, including unported VESA; not an executable server",
              "licenseReviewRequired": ["server.cpp historical mixed LGPL grant/GPL boilerplate; original notices retained"]}
    (OUT / "audit.json").write_text(json.dumps(record, indent=2) + "\n")
    if args.retain_evidence:
        evidence = ROOT / "docs/evidence/syllable-server-frontier-20261025"
        evidence.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUT / "audit.json", evidence / "audit.json")
        for row in rows:
            for suffix in ("-compile.txt", "-unresolved.txt"):
                path = OUT / (row["unit"] + suffix)
                if path.exists() and (suffix == "-compile.txt" or row["exitCode"] == 0):
                    shutil.copyfile(path, evidence / path.name)
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main())
