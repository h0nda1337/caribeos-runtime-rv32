#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain private-futex proof only after the entire actual matrix validates."""
import importlib.util
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-futex-v0.10"
CASES = tuple(f"{platform}-smp{cpus}-imacsu-native-sync-e-native-threads-d-futex-d-freetype-d-syllable-message"
              for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2)))
OFF = "opensbi-smp1-imacsu-native-threads-d-futex-disabled-native-areas"
REPEATS = ("futex-smp-repeat-01", "futex-smp-repeat-02")


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


threads = module("futex_thread_evidence", ROOT / "tools/collect-native-thread-evidence.py")
runner = module("futex_graphics_runner", ROOT / "scripts/test-graphics.py")


def current_artifacts():
    current = threads.current_artifacts()
    current["initrd"] = threads.sha(ROOT / "build/initrd-futex.img")
    current["nativeFutexProbe"] = threads.sha(ROOT / "build/native-futex-probe.elf")
    return current


def validate_case(source, current, disabled=False):
    if disabled:
        result = json.loads((source / "result.json").read_text())
        serial = (source / "serial.txt").read_text()
        if result.get("result") != "PASS" or result.get("baseIsa") != "rv32imac":
            raise RuntimeError("incomplete or wrong-ISA default-off run")
        for name, digest in current.items():
            if not name.startswith("freetype") and result.get("artifactSha256", {}).get(name) != digest:
                raise RuntimeError(f"stale {name} evidence")
        if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial:
            raise RuntimeError("missing actual Bash exit")
        profile = result.get("nativeThreads", {})
        if profile.get("gates") != list("ABCD") or profile.get("enabled") is not True or profile.get("libcThreading") is not False or profile.get("gnuThreadTls") is not False:
            raise RuntimeError("invalid raw-thread default-off dependency")
        for filename, digest in result.get("screenshots", {}).items():
            if Path(filename).name != filename or Path(filename).suffix != ".png" or threads.sha(source / filename) != digest:
                raise RuntimeError("modified or invalid scanout")
    else:
        result, serial = threads.validate_case(source, current)
    if runner.guest_failure(serial):
        raise RuntimeError("guest regression cannot be promoted")
    futex = result.get("nativeFutex", {})
    expected = ["off"] if disabled else list("ABCD")
    if futex.get("gates") != expected or futex.get("enabled") != (not disabled):
        raise RuntimeError("incomplete private-futex gates/profile")
    if futex.get("pthreadImplemented") is not False or futex.get("privateOnly") is not True:
        raise RuntimeError("unsupported pthread or shared-futex claim")
    if futex.get("createdReaped") != (1 if disabled else 89):
        raise RuntimeError("missing final reaper count")
    if not disabled and (futex.get("actualWakes"), futex.get("blockedCancellations"),
                         futex.get("ownerExitCycles")) != (10000, 64, 8):
        raise RuntimeError("incomplete actual wait/wake/lifecycle counters")
    gates = runner.validate_futex_log(serial, "D", disabled)
    for filename, expected_text in gates.items():
        if (source / filename).read_text() != expected_text:
            raise RuntimeError(f"gate log differs from actual serial: {filename}")
    return result, serial


def validate_rebuild(record, current):
    if record.get("result") != "PASS" or not record.get("after") or record.get("before") != record["after"]:
        raise RuntimeError("missing exact actual forced rebuild")
    expected = {"native_thread", "native_sync", "linux_syscall", "linux_process", "pmap",
                "riscv32_thread", "syscall", "trap", "native_futex", "sched_proto", "linux_exec"}
    units = record.get("forcedKernelUnits", [])
    if len(units) != 11 or set(units) != expected or len(record["after"]) != 13:
        raise RuntimeError("incomplete forced kernel/probe rebuild")
    expected_paths = {"xnu", "build/caribe_rv32.elf", "build/initrd.img", "build/initrd-threads.img",
        "build/native-thread-probe.elf", "build/freetype-probe.elf", "build/freetype-rv32-sysroot/usr/lib/libfreetype.a",
        "build/libcaribe-syllable-native.a", "build/libcaribe-syllable-string.a", "build/libcaribe-syllable-message.a",
        "build/font-sources.json", "build/native-futex-probe.elf", "build/initrd-futex.img"}
    if {row["path"] for row in record["after"]} != expected_paths:
        raise RuntimeError("missing or duplicate forced artifact")
    for row in record["after"]:
        path = row["path"]
        if path == "xnu":
            digest = current["xnu"]
        else:
            relative = Path(path)
            if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != "build":
                raise RuntimeError("invalid rebuild artifact path")
            digest = threads.sha(ROOT / relative)
        if row["sha256"] != digest:
            raise RuntimeError("stale forced rebuild")


def main():
    current = current_artifacts()
    checked = []
    for case in (*CASES, OFF):
        source = ROOT / "build/graphics-tests" / case
        result, serial = validate_case(source, current, case == OFF)
        expected_smp = 1 if case in (CASES[0], OFF) else 2
        if result.get("smp") != expected_smp or (result.get("bios") == "default") != case.startswith("opensbi"):
            raise RuntimeError("matrix platform/profile mismatch")
        checked.append((case, source, result, serial))
    for case in REPEATS:
        source = ROOT / "build" / case
        result, serial = validate_case(source, current)
        if result.get("smp") != 2 or result.get("bios") != "default":
            raise RuntimeError("invalid repeated SMP profile")
        checked.append((case, source, result, serial))
    rebuild_path = ROOT / "build/native-futex-rebuild.json"
    rebuild = json.loads(rebuild_path.read_text(encoding="utf-8-sig"))
    validate_rebuild(rebuild, current)
    kernel_log = threads.read_shell_log(ROOT / "build/native-futex-force-kernel.txt")
    if any(not re.search(rf"^CC {unit}\.o\r?$", kernel_log, re.M) for unit in rebuild["forcedKernelUnits"]):
        raise RuntimeError("missing actual forced compilation log")
    regression_path = ROOT / "build/native-thread-process-regression.txt"
    regression = threads.read_shell_log(regression_path)
    completed = re.findall(r"^OK: (\S+)\r?$", regression, re.M)
    expected = {"boot_stage1", *(f"boot_stage1_process_gate_{i}" + ("_only" if 7 <= i <= 10 else "") for i in range(2, 16))}
    if len(completed) != 15 or set(completed) != expected or "testproject.ps1 completed." not in regression:
        raise RuntimeError("incomplete actual process regression")
    proof_path = ROOT / "build/native-thread-process-regression.json"
    proof = json.loads(proof_path.read_text(encoding="utf-8-sig"))
    if proof.get("result") != "PASS" or proof.get("kernelBefore") != current["xnu"] or proof.get("kernelAfter") != current["xnu"] or proof.get("logSha256") != threads.sha(regression_path):
        raise RuntimeError("stale process regression/kernel proof")
    host_path = ROOT / "build/native-futex-host-tests.txt"
    host_log = threads.read_shell_log(host_path)
    host_count = re.search(r"Ran (\d+) tests", host_log)
    if not host_count or int(host_count[1]) < 84 or not re.search(r"^OK\r?$", host_log, re.M) or "FAILED (" in host_log:
        raise RuntimeError("incomplete actual host guards")
    # Validation above is read-only: an incomplete run cannot replace stable evidence.
    records = []
    for case, source, result, serial in checked:
        target = OUT / case
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]"))) + "\n")
        records.append({"case": case, "fullLocalSerialSha256": threads.sha(source / "serial.txt"),
                        "artifacts": result["artifactSha256"]})
    shutil.copyfile(rebuild_path, OUT / "rebuild.json")
    shutil.copyfile(proof_path, OUT / "process-regression.json")
    (OUT / "process-regression.txt").write_text("PASS 15 actual runner targets\nFull local log SHA-256: " +
        threads.sha(regression_path) + "\n" + "\n".join("OK: " + name for name in completed) + "\n")
    (OUT / "host-guards.txt").write_text(f"PASS {host_count[1]} actual unittest host guards; not guest proof\n" +
        "Full local log SHA-256: " + threads.sha(host_path) + "\n")
    snapshot = ROOT / "build/last-stable-futex-v0.10"
    snapshot.mkdir(parents=True, exist_ok=True)
    files = {"kernel.elf": ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
             "initrd-futex.img": ROOT / "build/initrd-futex.img", "native-futex-probe.elf": ROOT / "build/native-futex-probe.elf"}
    for name, source in files.items():
        shutil.copyfile(source, snapshot / name)
        if threads.sha(snapshot / name) != threads.sha(source):
            raise RuntimeError("stable snapshot copy differs")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": "2026-10-13", "result": "PASS", "cases": records,
        "scope": "opt-in native private futex WAIT/WAKE; not pthread/TLS or full Syllable AppServer",
        "currentArtifactSha256": current}, indent=2) + "\n")
    print("PASS retained actual private-futex matrix, default-off, regression and byte-identical rebuild")


if __name__ == "__main__":
    main()
