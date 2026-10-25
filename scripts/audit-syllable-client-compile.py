# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Audit actual complete GUI client units; unresolved work never becomes PASS."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT / "build/syllable-upstream-audit"
REV = "579e480a005321cc320e7e355e8dff398b689be8"
OUT = ROOT / "build/syllable-client-frontier"


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def verify_header(data, expected, name):
    if expected is None or not any(blob(candidate) == expected for candidate in
        (data, data.replace(b"\r\n", b"\n"), data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))):
        raise RuntimeError("unverified original header: " + name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--retain-evidence", action="store_true", help="Retain truthful partial compilation evidence, never a GUI runtime success")
    args = parser.parse_args()
    if not (REPO / ".git").exists():
        raise RuntimeError("Pinned upstream audit clone required at build/syllable-upstream-audit; see SYLLABLE_APPSERVER_BOUNDARY.md")
    actual = subprocess.check_output(["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True).strip()
    if actual != REV:
        raise RuntimeError("wrong upstream audit revision")
    tree = subprocess.check_output(["git", "-C", str(REPO), "ls-tree", "-rz", REV, "system/sys/include", "system/sys/appserver/libsyllable"])
    objects = {}
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, kind, digest = metadata.split()
        if kind == b"blob" and mode == b"100644":
            objects[path.decode()] = digest.decode()
    verified = []
    for path in sorted((ROOT / "third_party/syllable/system/sys/include").rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(ROOT / "third_party/syllable").as_posix()
        data = path.read_bytes()
        expected = objects.get(name)
        verify_header(data, expected, name)
        verified.append({"path": name, "upstreamGitBlob": expected, "localSha256": hashlib.sha256(data).hexdigest()})
    for path in sorted((OUT / "include").rglob("*")):
        if not path.is_file():
            continue
        alias = path.relative_to(OUT / "include").as_posix()
        original = "system/sys/include/" + ("atheos/sysinfo.h" if alias == "syllable/sysinfo.h" else alias)
        data = path.read_bytes()
        verify_header(data, objects.get(original), alias)
        verified.append({"path": original, "includeAs": alias, "upstreamGitBlob": objects[original], "localSha256": hashlib.sha256(data).hexdigest()})
    OUT.mkdir(parents=True, exist_ok=True)
    workspace = ROOT.parent.parent
    env = os.environ.copy()
    env["CARIBE_MUSL_SYSROOT"] = str(ROOT / "build/musl-heap-rv32-sysroot")
    env["TEMP"] = env["TMP"] = env["TMPDIR"] = str(workspace / "tmp")
    env["PATH"] = os.pathsep.join([str(workspace / "msys64/ucrt64/bin"), str(workspace / "msys64/usr/bin"), env.get("PATH", "")])
    cxx = ROOT / "build/cxx-rv32-sysroot/usr/include/c++/15.1.0"
    includes = [cxx, cxx / "riscv32-unknown-linux-musl", ROOT / "build/syllable-variant/include", ROOT / "ports/syllable/native",
                ROOT / "build/syllable-looper/native/include", ROOT / "build/syllable-looper/include", OUT / "include"]
    includes += [ROOT / "build" / name / "include" for name in ("syllable-looper-runtime", "syllable-queue", "syllable-thread", "syllable-locker", "syllable-string", "syllable-native")]
    includes.append(ROOT / "third_party/syllable/system/sys/include")
    flags = ["-O2", "-std=gnu++17", "-D_GNU_SOURCE", "-ffunction-sections", "-fdata-sections", "-msmall-data-limit=0", "-Wall", "-Wextra",
             "-DCARIBE_SYLLABLE_MESSAGE_CORE", "-DCARIBE_SYLLABLE_MESSAGE_DELIVERY", "-DCARIBE_SYLLABLE_MESSAGE_VARIANT",
             "-Ddbprintf=caribe_syllable_debug", "-include", "ports/syllable/native/looper_runtime.h", "-include", "string.h", "-include", "limits.h",
             "-include", "ports/syllable/native/atheos/types.h", *["-I" + str(path) for path in includes]]
    results = []
    for directory, unit in (("util", "application"), ("util", "invoker"), ("gui", "window"), ("gui", "view"), ("gui", "font"), ("gui", "control")):
        name = f"system/sys/appserver/libsyllable/{directory}/{unit}.cpp"
        data = subprocess.check_output(["git", "-C", str(REPO), "show", f"{REV}:{name}"])
        if blob(data) != objects[name]:
            raise RuntimeError("changed original client source")
        source = OUT / (unit + ".cpp")
        source.write_bytes(data)
        command = [str(workspace / "msys64/usr/bin/bash.exe"), "scripts/riscv32-musl-cxx.sh", *flags, "-c", str(source), "-o", str(OUT / (unit + ".o"))]
        for attempt in range(16):
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            missing = re.search(rb"fatal error: ([A-Za-z0-9_./-]+): No such file or directory", result.stdout)
            if not missing:
                break
            header = missing[1].decode()
            original = "system/sys/include/" + ("atheos/sysinfo.h" if header == "syllable/sysinfo.h" else header)
            if original not in objects:
                break
            data = subprocess.check_output(["git", "-C", str(REPO), "show", f"{REV}:{original}"])
            if blob(data) != objects[original]:
                raise RuntimeError("changed genuine GUI header input")
            target = OUT / "include" / header
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            verified.append({"path": original, "includeAs": header, "upstreamGitBlob": objects[original],
                             "localSha256": hashlib.sha256(data).hexdigest()})
        log = OUT / (unit + "-compile.txt")
        log.write_bytes(result.stdout)
        lines = result.stdout.decode(errors="replace").splitlines()
        errors = [line for line in lines if "error:" in line][:8]
        # Header fetching reuses 'data'; record the actual compiled source bytes.
        row = {"unit": unit, "sourceGitBlob": objects[name], "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
               "exitCode": result.returncode, "firstCompilerErrors": errors, "command": command,
               "compilerLogSha256": hashlib.sha256(log.read_bytes()).hexdigest()}
        if result.returncode == 0:
            target = OUT / (unit + ".o")
            elf = target.read_bytes()
            if elf[:7] != b"\x7fELF\x01\x01\x01" or elf[18:20] != b"\xf3\x00" or int.from_bytes(elf[36:40], "little") & 6:
                raise RuntimeError("GUI client object is not RV32 ELF/soft-float")
            symbols = subprocess.check_output([str(workspace / "msys64/ucrt64/bin/riscv64-unknown-elf-nm.exe"), "-C", "-u", str(target)])
            (OUT / (unit + "-unresolved.txt")).write_bytes(symbols)
            row.update(objectSha256=hashlib.sha256(elf).hexdigest(), unresolvedSha256=hashlib.sha256(symbols).hexdigest())
        results.append(row)
        print(unit, "COMPILED" if result.returncode == 0 else "UNPORTED", *errors, sep="\n  ", flush=True)
    complete = all(row["exitCode"] == 0 for row in results)
    record = {"result": "COMPILED_NOT_LINKED" if complete else "INCOMPLETE", "upstreamRevision": REV,
              "auditorSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "headers": verified, "sourcesModified": False, "linked": False,
              "runtimeVerified": False, "completeGui": False, "units": results,
              "scope": "Original complete client compilation frontier with genuine native dependency headers; not a running GUI",
              "compilerOnlyAdaptations": ["include string.h and limits.h", "map dbprintf to existing native bounded diagnostics", "historical sysinfo include alias retains complete original bytes"]}
    (OUT / "audit.json").write_text(json.dumps(record, indent=2) + "\n")
    if args.retain_evidence:
        evidence = ROOT / "docs/evidence/syllable-client-frontier-20261015"
        evidence.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUT / "audit.json", evidence / "audit.json")
        for row in results:
            for suffix in ("-compile.txt", "-unresolved.txt"):
                path = OUT / (row["unit"] + suffix)
                if path.exists() and (suffix == "-compile.txt" or row["exitCode"] == 0):
                    shutil.copyfile(path, evidence / path.name)
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main())
