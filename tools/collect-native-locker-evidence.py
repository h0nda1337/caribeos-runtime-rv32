#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain genuine Locker proof only after all current-source gates pass."""
import json
from pathlib import Path
import re
import shutil
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-locker-v0.12"
CASES = tuple(f"{platform}-smp{cpus}-imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-freetype-d-syllable-message"
              for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2)))
REPEATS = ("locker-smp-repeat-01", "locker-smp-repeat-02")
PROGRESSIVE = tuple(f"opensbi-smp1-imacsu-native-threads-a-futex-a-tcb-a-locker-{gate}-native-areas" for gate in "ab")
UNITS = ["native_locker_probe.cpp", "tcb_bootstrap.c", "thread_identity.c", "semaphore.c", "native_tcb_tls.S"]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


tcb = module("locker_tcb_evidence", ROOT / "tools/collect-native-tcb-evidence.py")
base, runner = tcb.base, tcb.runner
REBUILD_PATHS = tcb.REBUILD_PATHS | {"build/initrd-locker.img", "build/native-locker-probe.elf",
                                   "build/libcaribe-syllable-locker.a", "build/syllable-locker/sources.json"}


def current_artifacts():
    current = tcb.current_artifacts()
    current["initrd"] = base.sha(ROOT / "build/initrd-locker.img")
    for key, path in (("nativeLockerProbe", "build/native-locker-probe.elf"),
                      ("syllableLockerLibrary", "build/libcaribe-syllable-locker.a"),
                      ("syllableLockerSources", "build/syllable-locker/sources.json")):
        current[key] = base.sha(ROOT / path)
    return current


def validate_case(source, current):
    result, serial = tcb.validate_case(source, current)
    profile = result.get("nativeLocker", {})
    required = {"gates": list("ABC"), "source": "Syllable 579e480a005321cc320e7e355e8dff398b689be8 util/locker.h",
                "workers": 16, "cpu": 0, "protectedIncrements": 160000, "recursiveAcquisitions": 320000,
                "tryLockCycles": 64, "createdReaped": 80, "appServerBuilt": False, "pthreadLifecycleImplemented": False}
    if any(profile.get(key) != value for key, value in required.items()):
        raise RuntimeError("incomplete or unsupported original Locker profile")
    for name, content in runner.validate_locker_log(serial, "C").items():
        if (source / name).read_text() != content:
            raise RuntimeError(f"Locker gate log differs from serial: {name}")
    return result, serial


def verify_prepared_sources():
    preparer = module("locker_original_source", ROOT / "scripts/prepare-syllable-locker.py")
    source = ROOT / "build/syllable-locker"
    record = json.loads((source / "sources.json").read_text())
    if record.get("commit") != preparer.REV or record.get("license") != "LGPL-2.0-only":
        raise RuntimeError("incorrect Locker upstream revision/license")
    expected = [{"path": path, "sha256": sha, "license": "LGPL-2.0-only"} for path, sha in preparer.FILES.items()]
    if record.get("files") != expected:
        raise RuntimeError("incorrect Locker source pins")
    for path, sha in preparer.FILES.items():
        if base.sha(source / "upstream" / path) != sha:
            raise RuntimeError(f"modified original Locker input: {path}")
    if base.sha(source / "include/atheos/threads.h") != preparer.FILES["system/sys/include/atheos/threads.h"]:
        raise RuntimeError("modified genuine thread interface")
    if (record.get("patchSha256") != base.sha(ROOT / "ports/syllable/patches/locker-rv32.patch") or
            record.get("adaptedLockerSha256") != base.sha(source / "include/util/locker.h") or
            base.sha(source / "COPYING.LIB") != base.sha(ROOT / "ports/syllable/COPYING.LIB")):
        raise RuntimeError("modified Locker patch/adapted header/license")
    return record


def validate_rebuild(record, current):
    if (record.get("result") != "PASS" or record.get("before") != record.get("after")
            or record.get("kernelRecompiled") is not False or record.get("forcedUserUnits") != UNITS):
        raise RuntimeError("missing actual byte-identical Locker rebuild")
    rows = record.get("after", [])
    if len(rows) != len(REBUILD_PATHS) or {row["path"] for row in rows} != REBUILD_PATHS:
        raise RuntimeError("missing or duplicate Locker rebuild artifacts")
    for row in rows:
        digest = current["xnu"] if row["path"] == "xnu" else base.sha(ROOT / row["path"])
        if row["sha256"] != digest:
            raise RuntimeError("stale Locker rebuild artifact")


def validate_unchanged_baseline(current):
    baseline = tcb.validate_unchanged_kernel_baseline(current)
    prior = json.loads((ROOT / "docs/evidence/syllable-tcb-v0.11/manifest.json").read_text())
    for key, sha in prior["currentArtifactSha256"].items():
        digest = base.sha(ROOT / "build/initrd-tcb.img") if key == "initrd" else current.get(key)
        if sha != digest:
            raise RuntimeError(f"prior stable TCB dependency changed: {key}")
    return {"priorTcbSources": "syllable-tcb-v0.11/manifest.json", "allPriorArtifactHashesUnchanged": True,
            "processRegression": baseline}


def main():
    current = current_artifacts()
    sources = verify_prepared_sources()
    musl = module("locker_original_musl", ROOT / "tools/verify-musl-tcb-source.py").verify_sources(ROOT)
    baseline = validate_unchanged_baseline(current)
    checked = []
    for case in (*CASES, *REPEATS):
        source = ROOT / ("build/graphics-tests" if case in CASES else "build") / case
        result, serial = validate_case(source, current)
        if (result.get("smp") != (1 if case == CASES[0] else 2)
                or (result.get("bios") == "default") != (case != CASES[2])):
            raise RuntimeError("Locker matrix platform mismatch")
        checked.append((case, source, result, serial))
    for case, gate in zip(PROGRESSIVE, "AB"):
        source = ROOT / "build/graphics-tests" / case
        result = json.loads((source / "result.json").read_text())
        serial = (source / "serial.txt").read_text()
        if (result.get("result") != "PASS" or result.get("smp") != 1 or result.get("bios") != "default"
                or result.get("baseIsa") != "rv32imac" or result.get("nativeLocker", {}).get("gates") != list("AB"[:ord(gate)-ord("A")+1])):
            raise RuntimeError("missing actual progressive Locker gate")
        for key in ("xnu", "cbx", "initrd", "nativeLockerProbe", "syllableLockerLibrary", "syllableLockerSources"):
            if result.get("artifactSha256", {}).get(key) != current[key]:
                raise RuntimeError(f"stale progressive Locker {key}")
        if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial:
            raise RuntimeError("progressive Locker missing actual Bash exit")
        for name, content in runner.validate_locker_log(serial, gate).items():
            if (source / name).read_text() != content:
                raise RuntimeError("progressive Locker log differs from serial")
        checked.append((case, source, result, serial))
    record_path = ROOT / "build/native-locker-rebuild.json"
    validate_rebuild(json.loads(record_path.read_text(encoding="utf-8-sig")), current)
    log = base.read_shell_log(ROOT / "build/native-locker-force-probe.txt").replace("\\", "/")
    for marker in ("userland/native_locker_probe.cpp -o build/native_locker_probe.o",
                   "ports/syllable/native/tcb_bootstrap.c -o build/syllable_tcb_bootstrap.o",
                   "ports/syllable/native/thread_identity.c -o build/syllable_thread_identity.o",
                   "-DCARIBE_SYNC_RAW_TCB", "-o build/syllable_raw_semaphore.o", "-o build/syllable_semaphore.o",
                   "userland/native_tcb_tls.S -o build/native_tcb_tls.o", "wrote build/initrd-locker.img:"):
        if marker not in log:
            raise RuntimeError("missing actual Locker rebuild log")
    host_path = ROOT / "build/native-locker-host-tests.txt"
    host = base.read_shell_log(host_path)
    count = re.search(r"Ran (\d+) tests", host)
    if not count or int(count[1]) < 129 or not re.search(r"^OK\r?$", host, re.M) or "FAILED (" in host:
        raise RuntimeError("incomplete actual Locker host guards")
    # Prior evidence and stable snapshots stay untouched until all inputs pass.
    records = []
    for case, source, result, serial in checked:
        target = OUT / case
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]", "[native-locker]")))+"\n")
        records.append({"case": case, "fullLocalSerialSha256": base.sha(source / "serial.txt"), "artifacts": result["artifactSha256"]})
    shutil.copyfile(record_path, OUT / "rebuild.json")
    (OUT / "syllable-sources.json").write_text(json.dumps(sources, indent=2)+"\n")
    (OUT / "musl-sources.json").write_text(json.dumps(musl, indent=2)+"\n")
    (OUT / "host-guards.txt").write_text(f"PASS {count[1]} actual unittest host guards; not guest proof\nFull local log SHA-256: {base.sha(host_path)}\n")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": "2026-10-13", "result": "PASS", "cases": records,
        "scope": "genuine Syllable Locker with CPU0-bound native XNU workers; not Looper/AppServer or pthread lifecycle",
        "currentArtifactSha256": current, "unchangedKernelBaseline": baseline}, indent=2)+"\n")
    snapshot = ROOT / "build/last-stable-locker-v0.12"
    snapshot.mkdir(parents=True, exist_ok=True)
    for name, source in {"kernel.elf": ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
                         "initrd-locker.img": ROOT / "build/initrd-locker.img", "native-locker-probe.elf": ROOT / "build/native-locker-probe.elf"}.items():
        shutil.copyfile(source, snapshot / name)
        if base.sha(source) != base.sha(snapshot / name):
            raise RuntimeError("stable Locker snapshot differs")
    print("PASS retained actual original Locker progressive/repeated UP/SMP/SecureSBI matrix and byte-identical rebuild; v0.11 unchanged")


if __name__ == "__main__":
    main()
