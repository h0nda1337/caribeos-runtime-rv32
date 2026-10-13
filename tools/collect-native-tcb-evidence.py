#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Retain real TCB/TLS dependency proof without changing prior stable evidence."""
import json
from pathlib import Path
import re
import shutil
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/syllable-tcb-v0.11"
CASES = tuple(f"{platform}-smp{cpus}-imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-freetype-d-syllable-message"
              for platform, cpus in (("opensbi", 1), ("opensbi", 2), ("securesbi", 2)))
REPEATS = ("tcb-smp-repeat-01", "tcb-smp-repeat-02")
REBUILD_PATHS = {"xnu", "build/caribe_rv32.elf", "build/initrd.img", "build/initrd-threads.img", "build/initrd-futex.img",
    "build/initrd-tcb.img", "build/native-thread-probe.elf", "build/native-futex-probe.elf", "build/native-tcb-probe.elf",
    "build/musl-rv32-sysroot/usr/lib/libc.a", "build/freetype-probe.elf", "build/freetype-rv32-sysroot/usr/lib/libfreetype.a",
    "build/libcaribe-syllable-native.a", "build/libcaribe-syllable-string.a", "build/libcaribe-syllable-message.a", "build/font-sources.json"}


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


futex = module("tcb_futex_evidence", ROOT / "tools/collect-native-futex-evidence.py")
base = futex.threads
runner = futex.runner


def current_artifacts():
    current = futex.current_artifacts()
    current["initrd"] = base.sha(ROOT / "build/initrd-tcb.img")
    current["nativeTcbProbe"] = base.sha(ROOT / "build/native-tcb-probe.elf")
    current["muslLibrary"] = base.sha(ROOT / "build/musl-rv32-sysroot/usr/lib/libc.a")
    return current


def validate_case(source, current):
    result, serial = futex.validate_case(source, current)
    profile = result.get("nativeTcb", {})
    required = {"gates": list("ABC"), "muslVersion": "1.2.5", "nativeElfTls": True,
                "pthreadLifecycleImplemented": False, "threadedLibcImplemented": False,
                "cpu": 0, "workers": 16, "stressChecks": 160000, "reuseCycles": 64,
                "cancellationRequests": 16, "createdReaped": 96}
    if any(profile.get(key) != value for key, value in required.items()):
        raise RuntimeError("incomplete or unsupported musl TCB profile")
    for name, content in runner.validate_tcb_log(serial, "C").items():
        if (source / name).read_text() != content:
            raise RuntimeError(f"TCB gate log differs from serial: {name}")
    return result, serial


def validate_rebuild(record, current):
    if (record.get("result") != "PASS" or record.get("before") != record.get("after")
            or record.get("kernelRecompiled") is not False
            or record.get("forcedUserUnits") != ["native_tcb_probe.c", "native_tcb_tls.S"]):
        raise RuntimeError("missing actual byte-identical TCB rebuild")
    rows = record.get("after", [])
    if len(rows) != len(REBUILD_PATHS) or {row["path"] for row in rows} != REBUILD_PATHS:
        raise RuntimeError("missing or duplicate TCB rebuild artifacts")
    for row in rows:
        digest = current["xnu"] if row["path"] == "xnu" else base.sha(ROOT / row["path"])
        if row["sha256"] != digest:
            raise RuntimeError("stale TCB rebuild artifact")


def validate_unchanged_kernel_baseline(current):
    # Reuse is explicit: no claim that v0.10's long kernel suite was rerun here.
    prior = json.loads((ROOT / "docs/evidence/syllable-futex-v0.10/manifest.json").read_text())
    old = prior.get("currentArtifactSha256", {})
    for key in ("xnu", "cbx", "nativeThreadProbe", "nativeFutexProbe", "nativeIpcLibrary", "freetypeProbe", "freetypeLibrary"):
        if old.get(key) != current.get(key):
            raise RuntimeError(f"kernel/dependency changed from stable baseline: {key}")
    if old.get("initrd") != base.sha(ROOT / "build/initrd-futex.img"):
        raise RuntimeError("prior stable futex image changed")
    proof = json.loads((ROOT / "docs/evidence/syllable-futex-v0.10/process-regression.json").read_text())
    if proof.get("result") != "PASS" or proof.get("kernelBefore") != current["xnu"] or proof.get("kernelAfter") != current["xnu"]:
        raise RuntimeError("inapplicable prior process regression")
    return {"reusedNotRerun": True, "source": "syllable-futex-v0.10/process-regression.json",
            "kernel": current["xnu"], "priorFutexInitrd": old["initrd"]}


def main():
    current = current_artifacts()
    musl = module("tcb_original_musl", ROOT / "tools/verify-musl-tcb-source.py").verify_sources(ROOT)
    baseline = validate_unchanged_kernel_baseline(current)
    checked = []
    for case in (*CASES, *REPEATS):
        source = ROOT / ("build/graphics-tests" if case in CASES else "build") / case
        result, serial = validate_case(source, current)
        if (result.get("smp") != (1 if case == CASES[0] else 2)
                or (result.get("bios") == "default") != (case != CASES[2])):
            raise RuntimeError("TCB matrix platform mismatch")
        checked.append((case, source, result, serial))
    record_path = ROOT / "build/native-tcb-rebuild.json"
    rebuild = json.loads(record_path.read_text(encoding="utf-8-sig"))
    validate_rebuild(rebuild, current)
    build_log = base.read_shell_log(ROOT / "build/native-tcb-force-probe.txt").replace("\\", "/")
    for marker in ("userland/native_tcb_probe.c -o build/native_tcb_probe.o", "userland/native_tcb_tls.S -o build/native_tcb_tls.o",
                   "wrote build/initrd.img:", "wrote build/initrd-threads.img:", "wrote build/initrd-futex.img:", "wrote build/initrd-tcb.img:"):
        if marker not in build_log:
            raise RuntimeError("missing actual TCB rebuild log")
    host_path = ROOT / "build/native-tcb-host-tests.txt"
    host_log = base.read_shell_log(host_path)
    host_count = re.search(r"Ran (\d+) tests", host_log)
    if not host_count or int(host_count[1]) < 108 or not re.search(r"^OK\r?$", host_log, re.M) or "FAILED (" in host_log:
        raise RuntimeError("incomplete actual TCB host guards")
    # All gates, hashes, rebuild and baseline are read-only until this point.
    records = []
    for case, source, result, serial in checked:
        target = OUT / case
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix == ".png" or path.name.startswith("gate-") or path.name == "result.json":
                shutil.copyfile(path, target / path.name)
        (target / "boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(
            ("[smp-gate-", "[boot-report]", "[SecureSBI]", "[process-gate-11]", "[native-tcb]")))+"\n")
        records.append({"case": case, "fullLocalSerialSha256": base.sha(source / "serial.txt"), "artifacts": result["artifactSha256"]})
    shutil.copyfile(record_path, OUT / "rebuild.json")
    (OUT / "musl-sources.json").write_text(json.dumps(musl, indent=2)+"\n")
    (OUT / "host-guards.txt").write_text(f"PASS {host_count[1]} actual unittest host guards; not guest proof\nFull local log SHA-256: {base.sha(host_path)}\n")
    (OUT / "manifest.json").write_text(json.dumps({"recorded": "2026-10-13", "result": "PASS", "cases": records,
        "scope": "genuine musl TCB/errno/native ELF TLS; not pthread lifecycle, threaded libc or full Syllable AppServer",
        "currentArtifactSha256": current, "unchangedKernelBaseline": baseline}, indent=2)+"\n")
    snapshot = ROOT / "build/last-stable-tcb-v0.11"
    snapshot.mkdir(parents=True, exist_ok=True)
    for name, source in {"kernel.elf": ROOT.parent.parent / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
                         "initrd-tcb.img": ROOT / "build/initrd-tcb.img", "native-tcb-probe.elf": ROOT / "build/native-tcb-probe.elf"}.items():
        shutil.copyfile(source, snapshot / name)
        if base.sha(source) != base.sha(snapshot / name):
            raise RuntimeError("stable TCB snapshot differs")
    print("PASS retained actual musl TCB/TLS UP/SMP/SecureSBI/repeated matrix and byte-identical rebuild; kernel unchanged")


if __name__ == "__main__":
    main()
