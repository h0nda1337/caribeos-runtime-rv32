#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain original toolkit dispatch proof only after current-hash guest gates."""
import argparse
from datetime import date
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-dispatch-v0.16"


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


heap = module("dispatch_heap_proof", ROOT / "tools/collect-native-heap-evidence.py")
runner, base = heap.runner, heap.base
LOOPER_FILES = {"syllableLooperProbe": "build/syllable-looper-probe.elf",
                "syllableLooperLibrary": "build/libcaribe-syllable-looper.a",
                "syllableLooperSources": "build/syllable-looper-runtime/sources.json",
                "gnuNativeContextSources": "build/native-cxx-context/sources.json"}
MESSENGER_FILES = {"syllableMessengerProbe": "build/syllable-messenger-probe.elf",
                   "syllableMessengerLibrary": "build/libcaribe-syllable-messenger.a",
                   "syllableMessengerSources": "build/syllable-messenger/sources.json"}
REBUILD_PATHS = {"build/" + path for path in (
    "native-cxx-context/eh_globals.o", "native-cxx-context/eh_alloc.o", "native-cxx-context/sources.json",
    "syllable_cxx_context.o", "syllable_runtime_looper.o", "syllable_runtime_handler.o", "syllable_runtime_filter.o",
    "syllable_looper_runtime.o", "syllable_looper_probe.o", "libcaribe-syllable-looper.a",
    "syllable-looper-runtime/sources.json", "syllable-looper-probe.elf", "initrd-looper.img",
    "syllable_messenger.o", "syllable_delivery_message.o", "syllable_messenger_probe.o",
    "libcaribe-syllable-messenger.a", "syllable-messenger/sources.json", "syllable-messenger-probe.elf", "initrd-messenger.img")}
FULL = "imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c-freetype-d-looper-c"
CASES = [(f"{platform}-smp{cpus}-{FULL}-syllable-message", f"looper-{platform}-{cpus}", False)
         for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2))]
CASES += [(f"{platform}-smp{cpus}-{FULL}-messenger-c-syllable-message", f"messenger-{platform}-{cpus}", True)
          for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2))]


def current_artifacts(messenger):
    current = heap.current_artifacts()
    current["initrd"] = base.sha(ROOT / ("build/initrd-messenger.img" if messenger else "build/initrd-looper.img"))
    current.update({key: base.sha(ROOT / path) for key, path in LOOPER_FILES.items()})
    if messenger:
        current.update({key: base.sha(ROOT / path) for key, path in MESSENGER_FILES.items()})
    return current


def validate_case(source, current, messenger):
    result, serial = heap.validate_case(source, current)
    required = {"gates": list("ABC"), "cpu": 0, "originalLoop": True, "nativeGnuExceptionTls": True,
                "stdioThreaded": False, "fullGnuThreading": False, "appServerBuilt": False}
    if any((result.get("syllableLooper") or {}).get(key) != value for key, value in required.items()):
        raise RuntimeError("incomplete or unsupported original Looper profile")
    logs = runner.validate_looper_log(serial, "C")
    if messenger:
        required = {"gates": list("ABC"), "cpu": 0, "originalMessenger": True,
                    "originalReplyMethods": True, "independentExec": True, "variantImplemented": False, "appServerBuilt": False}
        if any((result.get("syllableMessenger") or {}).get(key) != value for key, value in required.items()):
            raise RuntimeError("incomplete original Messenger/cross-exec profile")
        logs.update(runner.validate_messenger_log(serial, "C"))
    for key in (*LOOPER_FILES, *(MESSENGER_FILES if messenger else {})):
        if result.get("artifactSha256", {}).get(key) != current[key]:
            raise RuntimeError("stale original toolkit dispatch artifact: " + key)
    for name, text in logs.items():
        if (source / name).read_text() != text:
            raise RuntimeError("dispatch gate log differs from actual UART: " + name)
    return result, serial


def verify_sources():
    heap.verify_sources()
    for name in ("looper", "messenger"):
        p = module("dispatch_" + name + "_pins", ROOT / f"scripts/prepare-syllable-{name}.py")
        out = ROOT / f"build/syllable-{name}"
        record = json.loads((out / "sources.json").read_text())
        if record.get("commit") != p.REV:
            raise RuntimeError("changed original toolkit revision")
        for path, digest in p.FILES.items():
            if base.sha(out / "upstream" / path) != digest:
                raise RuntimeError("changed original toolkit input: " + path)
    for directory, patch in (("syllable-looper-runtime", "looper-runtime-rv32.patch"),
                             ("syllable-messenger", "messenger-runtime-rv32.patch")):
        out = ROOT / "build" / directory
        record = json.loads((out / "sources.json").read_text())
        if record["patchSha256"] != base.sha(ROOT / "ports/syllable/patches" / patch):
            raise RuntimeError("changed dispatch source patch")
        for name, digest in record.get("adaptedFiles", record.get("adaptedSha256", {})).items():
            if base.sha(out / name) != digest:
                raise RuntimeError("changed adapted dispatch source: " + name)
    out = ROOT / "build/native-cxx-context"
    record = json.loads((out / "sources.json").read_text())
    pins = module("dispatch_native_gnu_pins", ROOT / "scripts/prepare-native-cxx-context.py")
    gnu = module("dispatch_gnu_archive_pins", ROOT / "scripts/prepare-cxx-deps.py")
    expected = [{"path": path, "sha256": digest} for path, digest in pins.FILES.items()]
    if (record.get("sourcesModified") is not False or record.get("gnuVersion") != "15.1.0" or
            record.get("files") != expected or record.get("archiveSha512") != gnu.SHA512 or
            gnu.digest(gnu.ARCHIVE, "sha512") != gnu.SHA512):
        raise RuntimeError("GNU native contexts are not original")
    for item in record["files"]:
        if base.sha(out / Path(item["path"]).name) != item["sha256"]:
            raise RuntimeError("changed genuine GNU exception input")
    for name in ("syllable-looper", "syllable-messenger"):
        runner.verify_looper_elf(ROOT / "build" / f"{name}-probe.elf")


def validate_rebuild(record):
    if (record.get("result") != "PASS" or record.get("before") != record.get("after") or
            record.get("includesMessenger") is not True or record.get("preservedStableArtifacts") != 38 or
            len(record.get("after", [])) != 20 or {row["path"] for row in record["after"]} != REBUILD_PATHS):
        raise RuntimeError("missing complete actual dispatch forced rebuild")
    for row in record["after"]:
        if base.sha(ROOT / row["path"]) != row["sha256"]:
            raise RuntimeError("stale actual dispatch rebuild")
    stable = json.loads((ROOT / "docs/evidence/syllable-heap-v0.15/rebuild.json").read_text())
    if len(stable["after"]) != 38:
        raise RuntimeError("missing complete stable baseline")
    for row in stable["after"]:
        digest = current_artifacts(False)["xnu"] if row["path"] == "xnu" else base.sha(ROOT / row["path"])
        if digest != row["sha256"]:
            raise RuntimeError("changed stable baseline artifact: " + row["path"])


def main():
    parser = argparse.ArgumentParser()
    checks = parser.add_mutually_exclusive_group()
    checks.add_argument("--check-looper", action="store_true", help="Read-only current-hash check of the three full Looper cases")
    checks.add_argument("--check-case", choices=[item[0] for item in CASES], help="Read-only full case verification without inline interpreter code")
    args = parser.parse_args()
    checked = []
    selected = [item for item in CASES if item[0] == args.check_case] if args.check_case else CASES[:3] if args.check_looper else CASES
    for case, slug, messenger in selected:
        source = ROOT / "build/graphics-tests" / case
        current = current_artifacts(messenger)
        result, serial = validate_case(source, current, messenger)
        if result.get("smp") != (1 if slug.endswith("-1") else 2) or (result.get("bios") == "default") != ("opensbi" in slug):
            raise RuntimeError("wrong platform/hart topology")
        checked.append((source, slug, result, serial))
    if args.check_looper or args.check_case:
        print("PASS actual current-hash full dispatch case(s); no new evidence written")
        return
    verify_sources()
    rebuild = json.loads((ROOT / "build/dispatch-rebuild.json").read_text())
    validate_rebuild(rebuild)
    failed_sources = []
    for directory, reason in (
            ("looper-c-initial-failure-20261015", "Initial real Looper C SIGSEGV after A/B; corrected original common/global-filter removal and strengthened lifecycle gates"),
            ("messenger-c-initial-failure-20261015", "Initial dependency service omitted original default Handler registration; fixed and rerun"),
            ("messenger-c-diagnostic-failure-20261015", "Instrumented same setup failure, sequence 0; original Looper started but service was not default"),
            ("messenger-full-smp-thread-B-failure-20261015", "Pre-existing unchanged Thread gate B counter assertion failed before Messenger; intermittent cause not fully isolated")):
        source = ROOT / "build" / directory / "serial.txt"
        if not source.exists():
            raise RuntimeError("missing preserved failed attempt: " + directory)
        failed_sources.append((source, directory, reason))
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for source, slug, result, serial in checked:
        target = OUT / slug
        target.mkdir(exist_ok=True)
        for path in source.iterdir():
            if path.is_file() and (path.name == "result.json" or path.name.startswith("gate-") or path.suffix == ".png"):
                shutil.copyfile(path, target / path.name)
        excerpt = [line for line in serial.splitlines() if any(token in line for token in
                   ("[syllable-looper", "[syllable-messenger", "SYLLABLE_LOOPER_STATUS=", "SYLLABLE_MESSENGER_STATUS=", "Bash exited status=0"))]
        (target / "dispatch-uart.txt").write_text("\n".join(excerpt) + "\n")
        entries.append({"case": source.name, "evidenceDirectory": slug, "fullLocalSerialSha256": base.sha(source / "serial.txt"),
                        "artifactSha256": result["artifactSha256"]})
    shutil.copyfile(ROOT / "build/dispatch-rebuild.json", OUT / "rebuild.json")
    for name in ("syllable-looper", "syllable-looper-runtime", "syllable-messenger", "native-cxx-context"):
        shutil.copyfile(ROOT / "build" / name / "sources.json", OUT / f"{name}-sources.json")
    failures = []
    for source, directory, reason in failed_sources:
        target = OUT / "known-failed-attempts"
        target.mkdir(exist_ok=True)
        (target / (directory + ".txt")).write_text("\n".join(source.read_text().splitlines()[-55:]) + "\n")
        failures.append({"directory": directory, "fullLocalSerialSha256": base.sha(source), "reason": reason})
    record = {"recorded": str(date.today()), "result": "PASS", "cases": entries,
              "kernelRecompiled": False, "priorLongKernelSuitesReexecuted": False,
              "stableDefaultProfile": "v0.15 remains unchanged", "appServerBuilt": False,
              "fullDesktopCompleted": False, "fullGnuThreading": False, "knownFailedAttempts": failures,
              "scope": "Original toolkit event dispatch/transport development checkpoint; not a stable desktop promotion"}
    (OUT / "manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    print("PASS six actual current-hash full dispatch cases and forced rebuild retained; not complete AppServer/Desktop")


if __name__ == "__main__":
    main()
