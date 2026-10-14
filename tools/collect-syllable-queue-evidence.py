#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Promote original MessageQueue proof only after actual current-hash gates."""
import argparse
from datetime import date
import importlib.util
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-queue-v0.14"
SUFFIX = "imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-freetype-d-syllable-message"
CASES = tuple(f"{platform}-smp{cpus}-{SUFFIX}" for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2)))
PROGRESSIVE = tuple(f"opensbi-smp1-imacsu-native-threads-{g}-futex-{g}-tcb-{g}-locker-{g}-threadapi-{g}-queue-{g}-syllable-message" for g in "ab")
REPEATS = ("queue-smp-repeat-01", "queue-smp-repeat-02")


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


parent = module("queue_thread_evidence", ROOT / "tools/collect-syllable-thread-evidence.py")
base, runner = parent.base, parent.runner
OLD = parent.CASES[:2]
CASE_SLUGS = dict(zip((*PROGRESSIVE, *CASES, *REPEATS, *OLD, *parent.OFF),
                     ("up-a", "up-b", "opensbi-up", "opensbi-smp-final", "securesbi-smp",
                      "smp-repeat-01", "smp-repeat-02", "thread-up", "thread-smp", "threads-off", "futex-off")))
NEW_FILES = {"syllableQueueProbe": "build/syllable-queue-probe.elf",
             "syllableQueueLibrary": "build/libcaribe-syllable-queue.a",
             "syllableQueueSources": "build/syllable-queue/sources.json"}
REBUILD_PATHS = parent.REBUILD_PATHS | set(NEW_FILES.values()) | {
    "build/initrd-queue.img", "build/syllable_queue.o", "build/syllable_raw_msgport.o", "build/syllable_msgport.o"}


def current_artifacts():
    current = parent.current_artifacts()
    current["initrd"] = base.sha(ROOT / "build/initrd-queue.img")
    current.update({key: base.sha(ROOT / path) for key, path in NEW_FILES.items()})
    return current


def verify_sources():
    parent.verify_sources()
    p = module("queue_original_pins", ROOT / "scripts/prepare-syllable-queue.py")
    source = ROOT / "build/syllable-queue"
    record = json.loads((source / "sources.json").read_text())
    expected = [{"path": path, "sha256": sha, "license": "LGPL-2.0-only"} for path, sha in p.FILES.items()]
    if record.get("files") != expected or record.get("commit") != p.REV or record.get("license") != "LGPL-2.0-only":
        raise RuntimeError("incorrect original Queue pins/license")
    for path, sha in p.FILES.items():
        if base.sha(source / "upstream" / path) != sha:
            raise RuntimeError("modified original Queue input")
        if "/include/" in path and base.sha(source / "include" / path.split("/include/", 1)[1]) != sha:
            raise RuntimeError("modified original Queue public header")
    if (record.get("patchSha256") != base.sha(ROOT / "ports/syllable/patches/messagequeue-rv32.patch") or
            record.get("adaptedQueueSha256") != base.sha(source / "messagequeue.cpp") or
            base.sha(source / "COPYING.LIB") != base.sha(ROOT / "ports/syllable/COPYING.LIB")):
        raise RuntimeError("modified Queue adapted source/patch/license")
    return record


def validate_case(source, current, gate="C", full=True):
    result, serial = parent.validate_case(source, current, gate, full)
    for key in NEW_FILES:
        if result.get("artifactSha256", {}).get(key) != current[key]:
            raise RuntimeError("stale MessageQueue artifact")
    required = {"gates": list("ABC"[:ord(gate)-ord("A")+1]), "cpu": 0,
                "source": "Syllable 579e480a005321cc320e7e355e8dff398b689be8 util/messagequeue.cpp",
                "queueCycles": 160000 if gate >= "B" else 0, "pingPongRounds": 10000 if gate >= "C" else 0,
                "createdReaped": 161 if gate >= "C" else 16 if gate >= "B" else 0,
                "cancelled": 64 if gate >= "C" else 0,
                "workerAllocations": False, "workerMessageDecode": False,
                "appServerBuilt": False, "threadedLibcImplemented": False}
    profile = result.get("syllableQueue") or {}
    if any(profile.get(key) != value for key, value in required.items()):
        raise RuntimeError("incomplete or unsupported Queue profile")
    for name, text in runner.validate_queue_log(serial, gate).items():
        if (source / name).read_text() != text:
            raise RuntimeError("Queue gate log differs from actual serial")
    return result, serial


def check_up_progressive(current):
    checked = []
    for case, gate in zip(PROGRESSIVE, "AB"):
        source = ROOT / "build/graphics-tests" / case
        result, serial = validate_case(source, current, gate, False)
        if result.get("smp") != 1 or result.get("bios") != "default":
            raise RuntimeError("wrong Queue progressive platform")
        checked.append((case, source, result, serial))
    source = ROOT / "build/graphics-tests" / CASES[0]
    result, serial = validate_case(source, current)
    if result.get("smp") != 1 or result.get("bios") != "default":
        raise RuntimeError("wrong Queue full UP platform")
    checked.append((CASES[0], source, result, serial))
    return checked


def validate_rebuild(record, current):
    rows = record.get("after", [])
    if (record.get("result") != "PASS" or record.get("before") != rows or
            record.get("forcedKernelUnits") != ["native_ipc", "syscall"] or
            record.get("forcedUserUnits") != ["messagequeue.cpp", "syllable_queue_probe.cpp", "msgport.c"] or
            record.get("priorThreadArtifactsUnchangedExceptKernel") is not True or
            len(rows) != len(REBUILD_PATHS) or {row["path"] for row in rows} != REBUILD_PATHS):
        raise RuntimeError("missing actual byte-identical Queue/IPC rebuild")
    for row in rows:
        digest = current["xnu"] if row["path"] == "xnu" else base.sha(ROOT / row["path"])
        if row["sha256"] != digest:
            raise RuntimeError("stale Queue rebuild artifact")


def validate_previous():
    prior = json.loads((ROOT / "docs/evidence/syllable-thread-v0.13/rebuild.json").read_text())
    for row in prior["after"]:
        path = (ROOT / "build/last-stable-thread-v0.13/kernel.elf") if row["path"] == "xnu" else ROOT / row["path"]
        if base.sha(path) != row["sha256"]:
            raise RuntimeError("prior stable Thread artifact changed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-up-progressive", action="store_true")
    args = parser.parse_args()
    current = current_artifacts()
    sources = verify_sources()
    checked = check_up_progressive(current)
    validate_previous()
    if args.check_up_progressive:
        print("PASS actual current-hash Queue progressive A/B and full UP, original source pins and stable v0.13 dependencies")
        return
    for case in (*CASES[1:], *REPEATS):
        source = ROOT / ("build/graphics-tests" if case in CASES else "build") / case
        result, serial = validate_case(source, current)
        if result.get("smp") != 2 or (result.get("bios") == "default") != (case != CASES[2]):
            raise RuntimeError("Queue matrix platform mismatch")
        checked.append((case, source, result, serial))
    for case, smp in zip(OLD, (1, 2)):
        source = ROOT / "build/graphics-tests" / case
        result, serial = parent.validate_case(source, parent.current_artifacts())
        if result.get("smp") != smp or result.get("bios") != "default" or result.get("syllableQueue") is not None:
            raise RuntimeError("wrong unchanged Thread profile")
        checked.append((case, source, result, serial))
    for case in parent.OFF:
        source = ROOT / "build/graphics-tests" / case
        if case == parent.OFF[0]:
            result, serial = base.validate_case(source, base.current_artifacts(), True)
        else:
            futex = parent.locker.tcb.futex
            result, serial = futex.validate_case(source, futex.current_artifacts(), True)
        if result.get("smp") != 1 or result.get("bios") != "default" or runner.guest_failure(serial):
            raise RuntimeError("wrong default-off Queue dependency platform")
        checked.append((case, source, result, serial))
    rebuild_path = ROOT / "build/queue-rebuild.json"
    rebuild = json.loads(rebuild_path.read_text(encoding="utf-8-sig"))
    validate_rebuild(rebuild, current)
    kernel_log = base.read_shell_log(ROOT / "build/queue-force-kernel.txt")
    for unit in ("native_ipc", "syscall"):
        if not re.search(rf"^CC {unit}\.o\r?$", kernel_log, re.M):
            raise RuntimeError("missing actual IPC/syscall compilation log")
    user_log = base.read_shell_log(ROOT / "build/queue-force-probe.txt").replace("\\", "/")
    for marker in ("build/syllable-queue/messagequeue.cpp -o build/syllable_queue.o",
                   "userland/syllable_queue_probe.cpp -o build/syllable_queue_probe.o",
                   "-o build/syllable_raw_msgport.o", "-o build/syllable_msgport.o", "wrote build/initrd-queue.img:"):
        if marker not in user_log:
            raise RuntimeError("missing actual Queue/raw/default adapter rebuild log")
    proof, completed = parent.validate_process_regression(current)
    host_path = ROOT / "build/queue-host-tests.txt"
    host = base.read_shell_log(host_path)
    count = re.search(r"Ran (\d+) tests", host)
    if not count or int(count[1]) < 206 or not re.search(r"^OK\r?$", host, re.M) or "FAILED (" in host:
        raise RuntimeError("incomplete Queue host guards")
    # Promotion is separate from experiments and follows every required current-hash gate.
    records = []
    for case, source, result, serial in checked:
        target = OUT / CASE_SLUGS[case]
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]", "[syllable-queue]"))) + "\n")
        records.append({"case": case, "evidenceDirectory": CASE_SLUGS[case],
                        "fullLocalSerialSha256": base.sha(source / "serial.txt"), "artifacts": result["artifactSha256"]})
    shutil.copyfile(rebuild_path, OUT / "rebuild.json")
    (OUT / "sources.json").write_text(json.dumps(sources, indent=2) + "\n")
    (OUT / "process-regression.json").write_text(json.dumps(proof, indent=2) + "\n")
    (OUT / "process-regression.txt").write_text("PASS 15 fresh actual runner targets\n" + "\n".join("OK: " + t for t in completed) + "\n")
    (OUT / "host-guards.txt").write_text(f"PASS {count[1]} host unit tests, not guest proof\nLocal log SHA-256: {base.sha(host_path)}\n")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": str(date.today()), "result": "PASS", "cases": records,
        "scope": "genuine MessageQueue/native CPU0 worker IPC; not Looper/AppServer or threaded libc",
        "currentArtifactSha256": current, "freshProcessRegression": True,
        "priorThreadArtifactsUnchangedExceptKernel": True}, indent=2) + "\n")
    snapshot = ROOT / "build/last-stable-queue-v0.14"
    snapshot.mkdir(parents=True, exist_ok=True)
    for name, source in {"kernel.elf": ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
                         "initrd-queue.img": ROOT / "build/initrd-queue.img",
                         "syllable-queue-probe.elf": ROOT / "build/syllable-queue-probe.elf"}.items():
        shutil.copyfile(source, snapshot / name)
        if base.sha(source) != base.sha(snapshot / name):
            raise RuntimeError("Queue stable snapshot differs")
    print("PASS retained original MessageQueue/worker IPC matrix, actual rebuild and fresh process regression; v0.13 preserved")


if __name__ == "__main__":
    main()
