#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain original typed GUI value evidence, never a complete desktop claim."""
import argparse
from datetime import date
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-variant-v0.17"


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


dispatch = module("variant_dispatch_evidence", ROOT / "tools/collect-syllable-dispatch-evidence.py")
base, runner = dispatch.base, dispatch.runner
FILES = {"syllableVariantProbe": "build/syllable-variant-probe.elf",
         "syllableVariantLibrary": "build/libcaribe-syllable-variant.a",
         "syllableVariantSources": "build/syllable-variant/sources.json"}
REBUILD_PATHS = set(FILES.values()) | {"build/syllable_variant.o", "build/syllable_variant_message.o",
                                    "build/syllable_variant_probe.o", "build/initrd-variant.img"}
PROGRESSIVE = "opensbi-smp1-imacsu-native-threads-a-futex-a-tcb-a-locker-a-threadapi-a-queue-a-heap-a-looper-a-messenger-a"
CASES = [(f"{PROGRESSIVE}-variant-{g.lower()}-syllable-message", f"up-{g.lower()}", g, False) for g in "AB"]
CASES += [(f"{platform}-smp{cpus}-{dispatch.FULL}-messenger-c-variant-c-syllable-message",
           f"{platform}-{cpus}", "C", True) for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2))]


def current_artifacts():
    current = dispatch.current_artifacts(True)
    current.update(runner.build_hashes(True, True, True, True, True, True))
    extra = {"nativeSyncProbe": "build/native-sync-probe.elf", "fontSources": "build/font-sources.json",
             "privateVmProbe": "build/private-vm-probe.elf", "nativeAreaProbe": "build/native-area-probe.elf",
             "nativeIpcProbe": "build/native-ipc-probe.elf", "nativeCxxProbe": "build/cxx-runtime-probe.elf",
             "gnuLibstdcxx": "build/cxx-rv32-sysroot/usr/lib/rv32imac/ilp32/libstdc++.a"}
    for component in ("String", "Message"):
        lower = component.lower()
        extra.update({f"syllable{component}Probe": f"build/syllable-{lower}-probe.elf",
                      f"syllable{component}Library": f"build/libcaribe-syllable-{lower}.a",
                      f"syllable{component}Sources": f"build/syllable-{lower}/sources.json"})
    current.update({key: base.sha(ROOT / path) for key, path in extra.items()})
    compiler = ROOT.parent.parent / "msys64/ucrt64/bin/riscv64-unknown-elf-g++.exe"
    for key, name in (("gnuCrtBegin", "crtbegin.o"), ("gnuCrtEnd", "crtend.o"), ("gnuLibgccUnwind", "libgcc.a")):
        path = subprocess.check_output([str(compiler), "-march=rv32imac_zicsr_zifencei", "-mabi=ilp32",
                                        f"-print-file-name={name}"], text=True).strip()
        current[key] = base.sha(Path(path))
    current["initrd"] = base.sha(ROOT / "build/initrd-variant.img")
    current.update({key: base.sha(ROOT / path) for key, path in FILES.items()})
    return current


def validate_case(source, current, gate, full):
    if full:
        result, serial = dispatch.validate_case(source, current, True)
    else:
        result, serial = dispatch.heap.validate_case(source, current, "A", False)
        for validator in (runner.validate_looper_log, runner.validate_messenger_log):
            for name, text in validator(serial, "A").items():
                if (source / name).read_text() != text:
                    raise RuntimeError("changed progressive dispatch log")
    required = {"gates": list("ABC"[:ord(gate)-ord("A")+1]), "cpu": 0,
                "originalVariant": True, "typedMessageMethods": True, "combinedDepthBudget": 16,
                "allocationFaultInjectionProbeOnly": True, "nonNullPointerWireSupported": False,
                "appServerBuilt": False}
    if any((result.get("syllableVariant") or {}).get(key) != value for key, value in required.items()):
        raise RuntimeError("incomplete or unsupported original Variant profile")
    for key, digest in result.get("artifactSha256", {}).items():
        if key not in current or current[key] != digest:
            raise RuntimeError("stale typed GUI value/dependency artifact: " + key)
    for key in FILES:
        if result.get("artifactSha256", {}).get(key) != current[key]:
            raise RuntimeError("missing original Variant artifact: " + key)
    for name, text in runner.validate_variant_log(serial, gate).items():
        if (source / name).read_text() != text:
            raise RuntimeError("Variant gate log differs from actual UART")
    if "\nSYLLABLE_VARIANT_STATUS=0\n" not in serial.replace("\r\n", "\n"):
        raise RuntimeError("missing actual typed-value process exit(0)")
    return result, serial


def verify_sources():
    dispatch.verify_sources()
    preparer = module("variant_source_pins", ROOT / "scripts/prepare-syllable-variant.py")
    source = ROOT / "build/syllable-variant"
    record = json.loads((source / "sources.json").read_text())
    expected = [{"path": path, "sha256": digest, "license": "LGPL-2.0-only"} for path, digest in preparer.FILES.items()]
    if (record.get("commit") != preparer.REV or record.get("files") != expected or
            record.get("patchSha256") != base.sha(ROOT / "ports/syllable/patches/variant-runtime-rv32.patch") or
            record.get("baseMessengerSourceSha256") != base.sha(ROOT / "build/syllable-messenger/sources.json") or
            record.get("maxWireBytes") != 8192 or record.get("maxCombinedMessageVariantDepth") != 16):
        raise RuntimeError("changed original Variant source/patch contract")
    for item in expected:
        if base.sha(source / "upstream" / item["path"]) != item["sha256"]:
            raise RuntimeError("changed pinned original Variant input")
    names = {"variant.cpp", "message.cpp", "include/util/variant.h", "include/util/message.h",
             "include/util/messenger.h", "include/util/flattenable.h", "include/util/typecodes.h"}
    if set(record.get("adaptedSha256", {})) != names:
        raise RuntimeError("incomplete original Variant adapted source inventory")
    for name, digest in record["adaptedSha256"].items():
        if base.sha(source / name) != digest:
            raise RuntimeError("changed adapted typed-value source")
    if base.sha(source / "COPYING.LIB") != base.sha(ROOT / "ports/syllable/COPYING.LIB"):
        raise RuntimeError("changed original Variant license notices")
    runner.verify_looper_elf(ROOT / "build/syllable-variant-probe.elf")


def validate_rebuild(record):
    rows = record.get("after", [])
    if (record.get("result") != "PASS" or record.get("before") != rows or
            len(rows) != len(REBUILD_PATHS) or {row["path"] for row in rows} != REBUILD_PATHS or
            record.get("preservedStableArtifacts") != 38 or record.get("preservedDispatchArtifacts") != 20 or
            record.get("kernelRecompiled") is not False or
            record.get("forcedRuntimeUnits") != ["variant.cpp", "message.cpp", "syllable_variant_probe.cpp"]):
        raise RuntimeError("missing complete actual Variant forced rebuild")
    for row in rows:
        if base.sha(ROOT / row["path"]) != row["sha256"]:
            raise RuntimeError("stale actual Variant rebuild artifact")
    # These checks cover all previous artifacts, not just the new test executable.
    dispatch.validate_rebuild(json.loads((ROOT / "docs/evidence/syllable-dispatch-v0.16/rebuild.json").read_text()))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-case", choices=[case[0] for case in CASES], help="Read-only current-hash case validation")
    args = parser.parse_args()
    checked = []
    current = current_artifacts()
    for case, slug, gate, full in CASES:
        if args.check_case and case != args.check_case:
            continue
        source = ROOT / "build/graphics-tests" / case
        result, serial = validate_case(source, current, gate, full)
        if result.get("smp") != (2 if slug.endswith("-2") else 1) or (result.get("bios") == "default") != (not slug.startswith("securesbi")):
            raise RuntimeError("wrong actual Variant firmware/hart topology")
        checked.append((source, slug, result, serial))
    if args.check_case:
        print("PASS actual current-hash original Variant case; no evidence written")
        return
    verify_sources()
    rebuild = json.loads((ROOT / "build/variant-rebuild.json").read_text())
    validate_rebuild(rebuild)
    log = base.read_shell_log(ROOT / "build/variant-force-runtime.txt").replace("\\", "/")
    for token in ("-c build/syllable-variant/variant.cpp", "-c build/syllable-variant/message.cpp",
                  "-c userland/syllable_variant_probe.cpp", "wrote build/initrd-variant.img:"):
        if token not in log:
            raise RuntimeError("missing actual original Variant forced compilation: " + token)
    host_path = ROOT / "build/variant-host-tests.txt"
    host = base.read_shell_log(host_path)
    count = re.search(r"Ran (\d+) tests", host)
    if not count or int(count[1]) < 295 or not re.search(r"^OK\r?$", host, re.M) or "FAILED (" in host:
        raise RuntimeError("incomplete typed-value host guards, not guest proof")
    failure_source = ROOT / "build/variant-b-guard-channel-failure-20261015/serial.txt"
    failure_text = failure_source.read_text()
    if "[syllable-variant] FAIL actual unmapped-access guard page" not in failure_text or "SYLLABLE_VARIANT_STATUS=1" not in failure_text:
        raise RuntimeError("missing retained actual guard-channel setup failure")
    # Do not create a success directory until every runtime and source gate passes.
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for source, slug, result, serial in checked:
        target = OUT / slug
        target.mkdir(exist_ok=True)
        for path in source.iterdir():
            if path.is_file() and (path.name == "result.json" or path.name.startswith("gate-") or path.suffix == ".png"):
                shutil.copyfile(path, target / path.name)
        excerpt = [line for line in serial.splitlines() if any(token in line for token in
                   ("[syllable-variant", "SYLLABLE_VARIANT_STATUS=", "Bash exited status=0"))]
        (target / "variant-uart.txt").write_text("\n".join(excerpt) + "\n")
        records.append({"case": source.name, "evidenceDirectory": slug, "fullLocalSerialSha256": base.sha(source / "serial.txt"),
                        "artifactSha256": result["artifactSha256"]})
    shutil.copyfile(ROOT / "build/variant-rebuild.json", OUT / "rebuild.json")
    shutil.copyfile(ROOT / "build/syllable-variant/sources.json", OUT / "variant-sources.json")
    failed = OUT / "known-failed-attempts"
    failed.mkdir(exist_ok=True)
    (failed / "guard-channel-uart.txt").write_text("\n".join(failure_text.splitlines()[-22:]) + "\n")
    (OUT / "host-guards.txt").write_text(f"PASS {count[1]} host tests, not guest proof\nLocal log SHA-256: {base.sha(host_path)}\n")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": str(date.today()), "result": "PASS", "cases": records,
        "currentArtifactSha256": current, "fullDesktopCompleted": False, "priorLongKernelSuitesReexecuted": False,
        "unchangedStableArtifacts": 38, "unchangedDispatchArtifacts": 20,
        "knownFailedAttempt": {"fullLocalSerialSha256": base.sha(failure_source),
            "reason": "Probe initially used the bounded allocator channel for PROT_NONE, which correctly returns ENOTSUP; fixed controller-only guard setup without kernel/allocator changes"},
        "scope": "Original Variant and Message typed-value transport; not Application/AppServer/Desktop"}, indent=2) + "\n")
    print("PASS original Variant progressive/full matrix, guarded decode, cross-exec and worker values; desktop remains incomplete")


if __name__ == "__main__":
    main()
