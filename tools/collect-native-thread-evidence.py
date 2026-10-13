#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain real completed raw-thread gates only after validating every input."""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-threads-v0.9"
CASES = tuple(f"{platform}-smp{cpus}-imacsu-native-sync-e-native-threads-d-freetype-d-syllable-message"
              for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2)))
OFF = "opensbi-smp1-imacsu-native-threads-disabled-native-areas"
PREFIXES = (("native-thread", "ABCD"), ("native-sync", "ABCDE"), ("native-ipc", "ABCD"),
            ("native-area", "ABCDE"), ("native-cxx", "ABCD"), ("syllable-string", "ABCD"),
            ("syllable-message", "ABCD"), ("freetype", "ABCD"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_shell_log(path):
    data = path.read_bytes()
    return data.decode("utf-16") if data.startswith((b"\xff\xfe", b"\xfe\xff")) else data.decode("utf-8-sig")


def current_artifacts():
    files = {"xnu": ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
             "cbx": ROOT / "build/caribe_rv32.elf", "initrd": ROOT / "build/initrd-threads.img",
             "nativeThreadProbe": ROOT / "build/native-thread-probe.elf",
             "nativeIpcLibrary": ROOT / "build/libcaribe-syllable-native.a",
             "freetypeProbe": ROOT / "build/freetype-probe.elf",
             "freetypeLibrary": ROOT / "build/freetype-rv32-sysroot/usr/lib/libfreetype.a"}
    return {name: sha(path) for name, path in files.items()}


def validate_case(source, current, disabled=False):
    result = json.loads((source / "result.json").read_text())
    if result.get("result") != "PASS" or result.get("baseIsa") != "rv32imac":
        raise RuntimeError("incomplete or wrong-ISA thread run")
    threads = result.get("nativeThreads", {})
    expected = ["off"] if disabled else list("ABCD")
    if threads.get("gates") != expected or threads.get("enabled") != (not disabled):
        raise RuntimeError("incomplete raw-thread gates/profile")
    if threads.get("libcThreading") is not False or threads.get("gnuThreadTls") is not False:
        raise RuntimeError("unsupported libc/GNU threading claim")
    for name, digest in current.items():
        if disabled and name.startswith("freetype"):
            continue
        if result.get("artifactSha256", {}).get(name) != digest:
            raise RuntimeError(f"stale {name} evidence")
    serial = (source / "serial.txt").read_text()
    if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial:
        raise RuntimeError("missing actual Bash exit")
    if result["smp"] == 2 and "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS" not in serial:
        raise RuntimeError("missing actual SMP F")
    if result["bios"] != "default" and "privileged signing DENIED PASS" not in serial:
        raise RuntimeError("missing SecureSBI privileged denial")
    if disabled:
        if "[native-thread] disabled-profile create=ENOTSUP no threads created PASS" not in serial:
            raise RuntimeError("missing default-off rejection")
        gates = (("native-thread", "disabled"),)
    else:
        for name in ("nativeIpc", "nativeAreas", "nativeCxx", "syllableString", "syllableMessage", "nativeSync", "freetype"):
            if not result.get(name):
                raise RuntimeError(f"missing selected dependency {name}")
        gates = PREFIXES
        if not re.search(r"same-pmap semaphore rounds=10000 acquisitions=20000 releases=20000 scheduler-waits=[1-9]\d*", serial):
            raise RuntimeError("missing actual same-task events")
        if not re.search(r"owner-exit cycles=16; created=reaped=35 preemptions=[1-9]\d* PASS", serial):
            raise RuntimeError("missing actual lifecycle/preemption")
        if "foreign process START/CANCEL/INFO/JOIN denied=64 owner unchanged PASS" not in serial:
            raise RuntimeError("missing actual ownership rejection")
        if result["nativeCxx"].get("threadModel") != "single":
            raise RuntimeError("unverified GNU thread model")
    for prefix, letters in gates:
        for gate in ([letters] if disabled else letters):
            if "PASS" not in (source / f"gate-{prefix}-{gate}.txt").read_text():
                raise RuntimeError(f"missing gate log {prefix}/{gate}")
    for filename, digest in result.get("screenshots", {}).items():
        if Path(filename).name != filename or Path(filename).suffix != ".png" or sha(source / filename) != digest:
            raise RuntimeError("modified or invalid scanout")
    return result, serial


def main():
    current = current_artifacts()
    checked = []
    for case in (*CASES, OFF):
        source = ROOT / "build/graphics-tests" / case
        result, serial = validate_case(source, current, case == OFF)
        checked.append((case, source, result, serial))
    rebuild_path = ROOT / "build/native-thread-rebuild.json"
    rebuild = json.loads(rebuild_path.read_text(encoding="utf-8-sig"))
    if rebuild.get("result") != "PASS" or not rebuild.get("after") or rebuild.get("before") != rebuild["after"]:
        raise RuntimeError("missing exact actual forced rebuild")
    for row in rebuild["after"]:
        digest = current["xnu"] if row["path"] == "xnu" else sha(ROOT / row["path"])
        if row["sha256"] != digest:
            raise RuntimeError("stale forced rebuild")
    regression_path = ROOT / "build/native-thread-process-regression.txt"
    regression = read_shell_log(regression_path)
    completed = re.findall(r"^OK: (\S+)\r?$", regression, re.M)
    expected = {"boot_stage1", *(f"boot_stage1_process_gate_{i}" + ("_only" if 7 <= i <= 10 else "") for i in range(2, 16))}
    if len(completed) != 15 or set(completed) != expected or "testproject.ps1 completed." not in regression:
        raise RuntimeError("incomplete actual process regression")
    proof = json.loads((ROOT / "build/native-thread-process-regression.json").read_text(encoding="utf-8-sig"))
    if proof.get("result") != "PASS" or proof.get("kernelBefore") != current["xnu"] or proof.get("kernelAfter") != current["xnu"] or proof.get("logSha256") != sha(regression_path):
        raise RuntimeError("stale process regression/kernel proof")
    # No retained files are changed until the entire matrix/rebuild/regression passes.
    records = []
    for case, source, result, serial in checked:
        target = OUT / case
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]"))) + "\n")
        records.append({"case": case, "fullLocalSerialSha256": sha(source / "serial.txt"), "artifacts": result["artifactSha256"]})
    shutil.copyfile(rebuild_path, OUT / "rebuild.json")
    shutil.copyfile(ROOT / "build/native-thread-process-regression.json", OUT / "process-regression.json")
    (OUT / "process-regression.txt").write_text("PASS 15 actual runner targets\nFull local log SHA-256: " + sha(regression_path) +
                                               "\n" + "\n".join("OK: " + name for name in completed) + "\n")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": "2026-10-13", "result": "PASS", "cases": records,
        "scope": "native shared-task raw user threads; not threaded libc/GNU TLS or full Syllable AppServer",
        "currentArtifactSha256": current}, indent=2) + "\n")
    print("PASS retained actual raw-thread matrix, default-off, process regression and byte-identical rebuild")


if __name__ == "__main__":
    main()
