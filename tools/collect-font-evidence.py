#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain current, complete genuine FreeType QEMU evidence, never partial PASS."""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-fonts-v0.8"
CASES = (
    "opensbi-smp1-imacsu-native-sync-e-freetype-d-syllable-message",
    "opensbi-smp2-imacsu-native-sync-e-freetype-d-syllable-message",
    "securesbi-smp2-imacsu-native-sync-e-freetype-d-syllable-message",
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    kernel = ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
    current = {"xnu": sha(kernel), "initrd": sha(ROOT / "build/initrd-fonts.img"),
               "freetypeProbe": sha(ROOT / "build/freetype-probe.elf"),
               "freetypeLibrary": sha(ROOT / "build/freetype-rv32-sysroot/usr/lib/libfreetype.a"),
               "fontSources": sha(ROOT / "build/font-sources.json")}
    baseline = json.loads((ROOT / "docs/evidence/syllable-sync-v0.7/manifest.json").read_text())
    if baseline["currentArtifactSha256"]["xnu"] != current["xnu"]:
        raise RuntimeError("prior kernel/process evidence cannot cover a changed kernel")
    rebuild_path = ROOT / "build/freetype-rebuild.json"
    rebuild = json.loads(rebuild_path.read_text(encoding="utf-8-sig"))
    if (rebuild.get("result") != "PASS" or not rebuild.get("after")
            or rebuild.get("before") != rebuild["after"]):
        raise RuntimeError("missing exact forced FreeType rebuild evidence")
    for item in rebuild["after"]:
        path = (ROOT / item["path"]).resolve()
        if not path.is_relative_to(ROOT.resolve()) or sha(path) != item["sha256"]:
            raise RuntimeError("stale/unsafe forced FreeType rebuild input")
    sources_path = ROOT / "build/font-sources.json"
    pins = json.loads(sources_path.read_text())
    if pins["freetype"]["commit"] != "37515cf56ba3349656049edbed89ffc6f6466f2d":
        raise RuntimeError("wrong FreeType source pin")
    checked, records = [], []
    for case in CASES:
        source = ROOT / "build/graphics-tests" / case
        result = json.loads((source / "result.json").read_text())
        if (result.get("result") != "PASS" or result["freetype"]["gates"] != list("ABCD")
                or result["freetype"]["engine"] != "2.15.0" or result["freetype"]["appServerBuilt"]):
            raise RuntimeError(f"missing complete genuine FreeType dependency PASS: {case}")
        if result["baseIsa"] != "rv32imac":
            raise RuntimeError(f"strict RV32IMAC CPU evidence missing: {case}")
        for key, expected in (("rasterRounds", 10000), ("truncations", 256),
                              ("invalidSignatures", 1024), ("allocationFailureCases", 32)):
            if result["freetype"].get(key) != expected:
                raise RuntimeError(f"incomplete FreeType counters: {case}/{key}")
        for name, digest in current.items():
            if result["artifactSha256"][name] != digest:
                raise RuntimeError(f"stale {name} evidence: {case}")
        if not all(result.get(name) for name in
                   ("nativeSync", "nativeIpc", "nativeAreas", "nativeCxx", "syllableString", "syllableMessage")):
            raise RuntimeError(f"missing compatibility dependency gates: {case}")
        serial = (source / "serial.txt").read_text()
        if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial:
            raise RuntimeError(f"missing real Bash exit: {case}")
        if result["smp"] == 2 and not re.search(r"\[smp-gate-f\][^\r\n]* PASS", serial):
            raise RuntimeError(f"missing SMP F: {case}")
        if not re.search(r"frame-fnv32=" + result["freetype"]["scanoutFnv32"] +
                         r" GPU-present zero-area-leak PASS", serial):
            raise RuntimeError(f"missing real shared framebuffer observation: {case}")
        for prefix, gates in (("freetype", "ABCD"), ("native-sync", "ABCDE"),
                              ("native-ipc", "ABCD"), ("native-area", "ABCDE"),
                              ("native-cxx", "ABCD"), ("syllable-string", "ABCD"),
                              ("syllable-message", "ABCD")):
            for gate in gates:
                lines = (source / f"gate-{prefix}-{gate}.txt").read_text().splitlines()
                if not lines or not all("PASS" in line for line in lines):
                    raise RuntimeError(f"missing gate log: {case}/{prefix}/{gate}")
        if "00-freetype-fonts.png" not in result["screenshots"]:
            raise RuntimeError(f"missing actual font scanout: {case}")
        for name, digest in result["screenshots"].items():
            if Path(name).name != name or not name.endswith(".png") or sha(source / name) != digest:
                raise RuntimeError(f"unsafe or changed scanout: {case}")
        checked.append((case, source, serial))
        records.append({"case": case, "fullLocalSerialSha256": sha(source / "serial.txt"),
                        "artifacts": result["artifactSha256"]})
    # No retained result is touched until every matrix, source and rebuild gate passed.
    for case, source, serial in checked:
        target = OUT / case; target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines()
            if line.startswith(("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]"))) + "\n")
    shutil.copyfile(sources_path, OUT / "sources.json")
    shutil.copyfile(rebuild_path, OUT / "rebuild.json")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": "2026-10-13", "result": "PASS",
        "cases": records, "currentArtifactSha256": current,
        "processRegression": "prior v0.7 matrix retained; exact kernel unchanged; not rerun or relabeled",
        "scope": "authentic FreeType dependency, not Syllable Font/SFont/AppServer/Desktop"}, indent=2) + "\n")
    print("PASS retained strict-ISA FreeType matrix, scanouts, pins and exact rebuild evidence")


if __name__ == "__main__":
    main()
