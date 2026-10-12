#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Build and run isolated SecureSBI/CBX signed-boot gates on Windows QEMU."""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent.parent
OUT = ROOT / "build/security-tests"


def run(command, log):
    print("Running:", " ".join(map(str, command)), flush=True)
    with (OUT / log).open("w", encoding="utf-8") as stream:
        result = subprocess.run(list(map(str, command)), cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        print((OUT / log).read_text(errors="replace")[-5000:])
        raise RuntimeError(f"command failed: see {OUT / log}")


def put_file(disk, source, path):
    spec = importlib.util.spec_from_file_location("hfs_update", ROOT / "scripts/update-hfs-kernel.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    image = helper.HFSPlusImage(disk)
    image.mount()
    try:
        image.find_file(path)
        exists = True
    except RuntimeError:
        exists = False
    finally:
        image.close()
    if exists:
        run([sys.executable, ROOT / "scripts/update-hfs-kernel.py", disk, source,
             "--path", path, "--allow-grow"], "hfs-update.txt")
    else:
        run([sys.executable, ROOT / "scripts/hfs-create-root-file.py", disk, path, source], "hfs-update.txt")


def boot(name, disk, elf, bios, required, smp=1, rejected=False, cpu=None):
    serial, error = OUT / f"{name}-serial.txt", OUT / f"{name}-qemu.txt"
    serial.write_bytes(b"")
    flags = "security=require" if required else ""
    if smp == 2:
        flags += " smp-start smp-gate-f"
    command = ["qemu-system-riscv32", "-M", "virt", "-m", "256", "-smp", str(smp),
               "-display", "none", "-monitor", "none", "-serial", f"file:{serial}",
               "-bios", str(bios), "-kernel", str(elf), "-snapshot", "-no-reboot",
               "-drive", f"if=none,file={disk},format=raw,id=vd0",
               "-device", "virtio-blk-device,drive=vd0", "-append", flags.strip()]
    if cpu:
        command += ["-cpu", cpu]
    marker = "[CaribeSecurity] RED:" if rejected else "[linux] exit status=0"
    with error.open("wb") as output:
        proc = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=output,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            deadline = time.monotonic() + 90
            while time.monotonic() < deadline:
                text = serial.read_text(errors="replace")
                if marker in text:
                    time.sleep(0.5)
                    break
                if proc.poll() is not None:
                    raise RuntimeError(f"{name}: QEMU exited: {error}")
                time.sleep(0.2)
            else:
                raise RuntimeError(f"{name}: timeout: {serial}")
        finally:
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
    text = serial.read_text(errors="replace")
    if marker not in text or "panic" in text or "unexpected trap" in text:
        raise RuntimeError(f"{name}: failed boot assertion: {serial}")
    if rejected:
        if "[ELF] saltando entry=" in text or "[XNU-CaribeOS]" in text or "cbx>" in text:
            raise RuntimeError(f"{name}: mandatory verification bypass")
    else:
        for expected in ("[XNU-CaribeOS]", "[musl-probe] PASS real musl libc",
                         "[gnu-bash] PASS arrays loops arithmetic",
                         "[boot-report] CaribeSecurity ORANGE root-unverified"):
            if expected not in text:
                raise RuntimeError(f"{name}: missing {expected}")
        if required:
            for subject in ("kernel.elf", "initrd.img"):
                if f"Ed25519/SHA-256 verified: {subject}" not in text:
                    raise RuntimeError(f"{name}: missing verified {subject}")
        if smp == 2 and "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS" not in text:
            raise RuntimeError(f"{name}: SMP Gate F did not pass")
    if bios != "default":
        for expected in ("CaribeSSBI negotiated version=0x00010000 capabilities=0x00000007",
                         "privileged signing DENIED PASS", "discovery ABI error paths PASS"):
            if expected not in text:
                raise RuntimeError(f"{name}: missing {expected}")
    if "[CaribeSecurity] GREEN" in text or "[CaribeSecurity] YELLOW" in text:
        raise RuntimeError(f"{name}: elevated trust without an authenticated root")
    print(f"PASS {name}: {serial}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-kernel", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    # Use this interpreter for cryptography; MSYS Python is only a build tool.
    os.environ["PATH"] = str(WORKSPACE / "msys64/ucrt64/bin") + os.pathsep + str(WORKSPACE / "msys64/usr/bin") + os.pathsep + os.environ["PATH"]
    run([sys.executable, ROOT / "scripts/prepare-security-deps.py"], "deps.txt")
    run([sys.executable, ROOT / "tests/test_catkey.py"], "catkey-tests.txt")
    securesbi = WORKSPACE / "securesbi"
    if (ROOT / "include/uapi/caribe_ssbi.h").read_bytes() != (securesbi / "include/sbi/caribe_ssbi.h").read_bytes():
        raise RuntimeError("firmware and supervisor ABI headers differ")
    run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
         securesbi / "scripts/caribe/build-rv32.ps1"], "firmware-build.txt")
    if args.build_kernel:
        run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
             WORKSPACE / "xnu-2050.48.11/tools/riscv32-link-full-stage0.ps1"], "kernel-build.txt")
    kernel = WORKSPACE / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
    initrd = ROOT / "build/initrd.img"
    bios = securesbi / "build/platform/generic/firmware/fw_dynamic.bin"
    signed, unsigned = OUT / "signed.img", OUT / "unsigned.img"
    shutil.copyfile(ROOT / "hfsplus.img", unsigned)
    put_file(unsigned, kernel, "/kernel.elf")
    put_file(unsigned, initrd, "/initrd.img")
    shutil.copyfile(unsigned, signed)
    key_root = WORKSPACE / "tmp"
    key_root.mkdir(exist_ok=True)
    results = []
    signer = ROOT / "tools/catkey.py"
    with tempfile.TemporaryDirectory(prefix="caribe-dev-signing-", dir=key_root) as keys:
        private, public = Path(keys) / "development.pem", OUT / "development.pub"
        if public.exists():
            public.unlink()
        run([sys.executable, signer, "keygen", "--private", private, "--public", public], "keygen.txt")
        header = OUT / "development-trust.h"
        run([sys.executable, signer, "enroll-header", "--public", public, "--output", header], "enroll.txt")
        run(["make", "-W", "booter/caribe_security.c", "all",
             "DEV_TRUST_HEADER=build/security-tests/development-trust.h"], "booter-build.txt")
        elf = OUT / "signed-booter.elf"
        shutil.copyfile(ROOT / "build/caribe_rv32.elf", elf)
        try:
            for subject, image, permission in (("kernel.elf", kernel, "kernel"), ("initrd.img", initrd, "initrd")):
                record = OUT / (subject + ".catkey")
                run([sys.executable, signer, "sign-image", "--private", private, "--record", record,
                     "--image", image, "--subject", subject, "--permission", permission], f"sign-{permission}.txt")
                run([sys.executable, signer, "verify-image", "--public", public, "--record", record,
                     "--image", image, "--subject", subject, "--permission", permission], f"verify-{permission}.txt")
                put_file(signed, record, f"/{permission}.catkey")
            for name, disk, firmware, policy, smp in (
                ("standard-orange-up", unsigned, "default", False, 1),
                ("securesbi-orange-up", unsigned, bios, False, 1),
                ("signed-standard-up", signed, "default", True, 1),
                ("signed-securesbi-up", signed, bios, True, 1),
                ("signed-securesbi-smp", signed, bios, True, 2),
            ):
                boot(name, disk, elf, firmware, policy, smp)
                results.append({"name": name, "result": "PASS"})
            boot("signed-securesbi-no-h", signed, elf, bios, True, cpu="rv32,h=false")
            results.append({"name": "signed-securesbi-no-h", "result": "PASS"})
            for name, kind in (("missing-manifest", "missing"), ("modified-manifest", "body"),
                               ("incorrect-signature", "signature"), ("modified-kernel", "kernel"),
                               ("modified-initrd", "initrd"), ("oversized-manifest", "oversized"),
                               ("oversized-permissive", "oversized"), ("empty-permissive", "empty")):
                disk = OUT / "negative.img"
                shutil.copyfile(unsigned if kind == "missing" else signed, disk)
                if kind in ("body", "signature"):
                    damaged = bytearray((OUT / "kernel.elf.catkey").read_bytes())
                    damaged[32 if kind == "body" else 170] ^= 1
                    bad = OUT / "bad.catkey"
                    bad.write_bytes(damaged)
                    put_file(disk, bad, "/kernel.catkey")
                elif kind in ("kernel", "initrd"):
                    damaged = bytearray((kernel if kind == "kernel" else initrd).read_bytes())
                    damaged[-1] ^= 1
                    bad = OUT / "damaged-payload"
                    bad.write_bytes(damaged)
                    put_file(disk, bad, "/kernel.elf" if kind == "kernel" else "/initrd.img")
                elif kind in ("oversized", "empty"):
                    bad = OUT / "bad.catkey"
                    bad.write_bytes((OUT / "kernel.elf.catkey").read_bytes() + b"x" if kind == "oversized" else b"")
                    put_file(disk, bad, "/kernel.catkey")
                boot(name, disk, elf, bios, "permissive" not in name, rejected=True)
                results.append({"name": name, "result": "PASS"})
            for name, firmware, disk, smp in (("bash-standard-up", "default", unsigned, 1),
                                             ("bash-signed-securesbi-smp", bios, signed, 2)):
                command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                           ROOT / "scripts/qemu-rv32-bash-interactive.ps1", "-Seconds", "120",
                           "-Bios", firmware, "-BootElf", elf, "-DiskImage", disk, "-Smp", str(smp)]
                if smp == 2:
                    command += ["-RequireSmpGateF", "-Append", "security=require smp-start smp-gate-f process-gate-11"]
                run(command, f"{name}-run.txt")
                shutil.copyfile(ROOT / "build/serial.log", OUT / f"{name}-serial.txt")
                print(f"PASS {name}", flush=True)
                results.append({"name": name, "result": "PASS"})
        finally:
            # Restore ordinary unsigned/permissive build; test key never persists in it.
            run(["make", "-W", "booter/caribe_security.c", "all"], "booter-default-build.txt")
        if "#define CARIBE_DEV_PUBLIC_KEY {0}" not in (ROOT / "build/security-config.h").read_text():
            raise RuntimeError("development enrollment persisted in the default build")
        boot("default-enrollment-cleared", signed, ROOT / "build/caribe_rv32.elf", bios,
             True, rejected=True)
        results.append({"name": "default-enrollment-cleared", "result": "PASS"})
    (OUT / "results.json").write_text(json.dumps({"qemu": results, "hardware_root": "UNAVAILABLE",
                                                 "green_state": "NOT_TESTED"}, indent=2) + "\n")
    print(f"CaribeSecurity gates PASS: {len(results)} QEMU cases; evidence in {OUT}")


if __name__ == "__main__":
    main()
