#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain completed native-sync QEMU evidence, refusing stale/partial results."""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-sync-v0.7"
CASES = (
    "opensbi-smp1-native-sync-e-syllable-message",
    "opensbi-smp2-imacsu-native-sync-e-syllable-message",
    "securesbi-smp2-imacsu-native-sync-e-syllable-message",
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def retain(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != source.read_bytes():
        shutil.copyfile(source, target)


def main():
    kernel = ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
    current = {"xnu": sha(kernel), "initrd": sha(ROOT / "build/initrd-sync.img"),
               "nativeSyncProbe": sha(ROOT / "build/native-sync-probe.elf"),
               "nativeIpcLibrary": sha(ROOT / "build/libcaribe-syllable-native.a")}
    records = []
    checked = []
    for case in CASES:
        source = ROOT / "build/graphics-tests" / case
        result = json.loads((source / "result.json").read_text())
        if result["result"] != "PASS" or result["nativeSync"]["gates"] != list("ABCDE"):
            raise RuntimeError(f"missing complete native-sync PASS: {case}")
        for name, digest in current.items():
            if result["artifactSha256"][name] != digest:
                raise RuntimeError(f"stale {name} evidence: {case}")
        if not all(result.get(name) for name in ("nativeIpc", "nativeAreas", "nativeCxx", "syllableString", "syllableMessage")):
            raise RuntimeError(f"missing selected dependency gates: {case}")
        serial = (source / "serial.txt").read_text()
        if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial:
            raise RuntimeError(f"missing actual Bash exit: {case}")
        if result["smp"] == 2 and not re.search(r"\[smp-gate-f\][^\r\n]* PASS", serial):
            raise RuntimeError(f"missing SMP F: {case}")
        if "imacsu" in case and result["baseIsa"] != "rv32imac":
            raise RuntimeError(f"wrong strict ISA: {case}")
        for prefix, gates in (("native-sync", "ABCDE"), ("native-ipc", "ABCD"),
                              ("native-area", "ABCDE"), ("native-cxx", "ABCD"),
                              ("syllable-string", "ABCD"), ("syllable-message", "ABCD")):
            for gate in gates:
                if "PASS" not in (source / f"gate-{prefix}-{gate}.txt").read_text():
                    raise RuntimeError(f"missing gate log: {case}/{prefix}/{gate}")
        for filename, digest in result["screenshots"].items():
            if sha(source / filename) != digest:
                raise RuntimeError(f"modified scanout: {case}/{filename}")
        checked.append((case, source, serial))
        records.append({"case": case, "fullLocalSerialSha256": sha(source / "serial.txt"),
                        "artifacts": result["artifactSha256"]})
    process = ROOT / "build/native-sync-process-regression.txt"
    lines = process.read_text(encoding="utf-8-sig").splitlines()
    targets = [line for line in lines if line.startswith(("==> make ", "OK: "))]
    completions = [line.removeprefix("OK: ") for line in targets if line.startswith("OK: ")]
    expected = {"boot_stage1", *(f"boot_stage1_process_gate_{i}" + ("_only" if 7 <= i <= 10 else "")
                                for i in range(2, 16))}
    if len(completions) != 15 or set(completions) != expected:
        raise RuntimeError("process regression did not complete 15 runner targets")
    if not any(line == "testproject.ps1 completed." for line in lines):
        raise RuntimeError("missing process runner completion marker")
    summary = "PASS all 15 actual process runner targets\nFull local log SHA-256: " + sha(process) + "\n"
    summary += "\n".join(targets) + "\n"
    sources = (
            (ROOT / "build/syllable-native/sources.json", "native-sources.json"),
            (ROOT / "build/syllable-message/sources.json", "message-sources.json"),
            (ROOT / "build/native-sync-rebuild.json", "rebuild.json"))
    rebuild = json.loads(sources[-1][0].read_text(encoding="utf-8-sig"))
    if rebuild["result"] != "PASS" or rebuild["before"] != rebuild["after"]:
        raise RuntimeError("missing exact forced rebuild verification")
    if not rebuild["after"]:
        raise RuntimeError("empty forced rebuild verification")
    for item in rebuild["after"]:
        if item["sha256"] != sha(ROOT / item["path"]):
            raise RuntimeError(f"stale forced rebuild artifact: {item['path']}")
    for case, source, serial in checked:
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                retain(path, OUT / case / path.name)
        boot = "\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]"))) + "\n"
        (OUT / case / "boot-summary.txt").write_text(boot)
    (OUT / "process-regression.txt").write_text(summary)
    for source, filename in sources:
        retain(source, OUT / filename)
    manifest = {"recorded": "2026-10-13", "result": "PASS", "cases": records,
                "scope": "native counting semaphores, not native user threads or complete AppServer",
                "currentArtifactSha256": current}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("PASS retained current native-sync matrix, process targets and forced rebuild evidence")


if __name__ == "__main__":
    main()
