#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Compile complete unmodified upstream units; report real native port blockers."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/syllable-looper"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-handler", action="store_true", help="compile the auditable native Handler adaptation")
    parser.add_argument("--native-looper", action="store_true", help="compile full Looper/Handler with native platform headers, without linking")
    parser.add_argument("--retain-evidence", action="store_true", help="retain successful compilation inputs/logs, never boot proof")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("looper_inputs", ROOT / "scripts/prepare-syllable-looper.py")
    inputs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inputs)
    inputs.main()
    workspace = ROOT.parent.parent
    env = os.environ.copy()
    env["PATH"] = os.pathsep.join([str(workspace / "msys64/ucrt64/bin"),
                                  str(workspace / "msys64/usr/bin"), env.get("PATH", "")])
    env["CARIBE_MUSL_SYSROOT"] = str(ROOT / "build/musl-heap-rv32-sysroot")
    bash = workspace / "msys64/usr/bin/bash.exe"
    compiler = workspace / "msys64/ucrt64/bin/riscv64-unknown-elf-g++.exe"
    env["CARIBE_RISCV32_CXX"] = compiler.as_posix()
    cxx = ROOT / "build/cxx-rv32-sysroot/usr/include/c++/15.1.0"
    flags = ["-O2", "-std=gnu++17", "-D_GNU_SOURCE", "-ffunction-sections", "-fdata-sections",
             "-msmall-data-limit=0", "-Wall", "-Wextra", "-DCARIBE_SYLLABLE_MESSAGE_CORE",
             "-include", "ports/syllable/native/atheos/types.h"]
    flags += ["-I" + str(p) for p in (cxx, cxx / "riscv32-unknown-linux-musl",
              ROOT / "ports/syllable/native", OUT / "include", ROOT / "build/syllable-thread/include",
              ROOT / "build/syllable-locker/include", ROOT / "build/syllable-queue/include",
              ROOT / "build/syllable-message/include", ROOT / "build/syllable-string/include",
              ROOT / "build/syllable-native/include", ROOT / "third_party/syllable/system/sys/include")]
    if args.native_looper:
        flags.insert(0, "-I" + str(OUT / "native/include"))
    for required in (bash, compiler, cxx, ROOT / "build/musl-heap-rv32-sysroot/usr/lib/libc.a"):
        if not required.exists():
            raise RuntimeError("genuine heap/C++ prerequisites missing; no host-compiler fallback")
    results = []
    for unit in ("handler", "messagefilter", "looper"):
        adapted = ((args.native_handler or args.native_looper) and unit == "handler") or (args.native_looper and unit == "looper")
        source = OUT / (unit + ".cpp") if adapted else OUT / "src" / (unit + ".cpp")
        target = OUT / (unit + ".o")
        command = [str(bash), "scripts/riscv32-musl-cxx.sh", *flags, "-c", str(source), "-o", str(target)]
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log = OUT / (unit + "-compile.txt")
        log.write_bytes(result.stdout)
        row = {"unit": unit, "nativeAdaptation": adapted, "sourceSha256": sha(source), "command": command,
               "exitCode": result.returncode, "logSha256": sha(log), "result": "COMPILED" if result.returncode == 0 else "BLOCKED"}
        if result.returncode == 0:
            header = target.read_bytes()[:20]
            if header[:7] != b"\x7fELF\x01\x01\x01" or header[18:20] != b"\xf3\x00":
                raise RuntimeError("compiler output is not RV32 little-endian RISC-V ELF")
            row["objectSha256"] = sha(target)
        results.append(row)
        kind = "native-adapted" if adapted else "original"
        print(f"{row['result']} {kind} {unit}.cpp: compiler exit={result.returncode}; log={log}")
    record = {"result": "COMPILED" if all(r["exitCode"] == 0 for r in results) else "BLOCKED",
              "commit": inputs.REV, "sourcesModified": args.native_handler or args.native_looper,
              "linked": False, "runtimeVerified": False, "nodeMonitorImplemented": False,
              "scope": "complete original unit compilation audit only; not a running Looper/AppServer", "units": results}
    (OUT / "compile-audit.json").write_bytes((json.dumps(record, indent=2) + "\n").encode())
    if args.retain_evidence:
        if record["result"] != "COMPILED":
            raise RuntimeError("refusing to retain incomplete compilation as a successful checkpoint")
        nm = workspace / "msys64/ucrt64/bin/riscv64-unknown-elf-nm.exe"
        symbols = subprocess.check_output([str(nm), "-C", "-u", *[str(OUT / (r["unit"] + ".o")) for r in results]])
        evidence = ROOT / "docs/evidence/syllable-looper-compilation"
        evidence.mkdir(parents=True, exist_ok=True)
        for name in ("sources.json", "compile-audit.json", *[r["unit"] + "-compile.txt" for r in results]):
            shutil.copyfile(OUT / name, evidence / name)
        (evidence / "unresolved-symbols.txt").write_bytes(symbols)
    return 0 if record["result"] == "COMPILED" else 1


if __name__ == "__main__":
    sys.exit(main())
