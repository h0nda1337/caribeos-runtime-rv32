#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Validate actual Thread matrix/rebuild/regression before a separate promotion."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/evidence/syllable-thread-v0.13"
SUFFIX="imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-freetype-d-syllable-message"
CASES=tuple(f"{platform}-smp{cpus}-{SUFFIX}" for platform,cpus in (("opensbi",1),("opensbi",2),("securesbi",2)))
REPEATS=("threadapi-smp-repeat-01","threadapi-smp-repeat-02")
PROGRESSIVE=tuple(f"opensbi-smp1-imacsu-native-threads-{g}-futex-{g}-tcb-{g}-locker-{g}-threadapi-{g}-native-areas" for g in "ab")
OFF=("opensbi-smp1-imacsu-native-threads-disabled-native-areas",
     "opensbi-smp1-imacsu-native-threads-d-futex-disabled-native-areas")
CASE_SLUGS=dict(zip((*PROGRESSIVE,*CASES,*REPEATS,*OFF),
                   ("up-a","up-b","opensbi-up","opensbi-smp-final","securesbi-smp",
                    "smp-repeat-01","smp-repeat-02","threads-off","futex-off")))
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path); value=importlib.util.module_from_spec(spec); spec.loader.exec_module(value); return value
locker=module("threadapi_locker_evidence",ROOT/"tools/collect-native-locker-evidence.py")
base,runner=locker.base,locker.runner
NEW_FILES={"syllableThreadProbe":"build/syllable-thread-probe.elf",
           "syllableThreadLibrary":"build/libcaribe-syllable-thread.a",
           "syllableThreadSources":"build/syllable-thread/sources.json"}
REBUILD_PATHS=locker.REBUILD_PATHS | set(NEW_FILES.values()) | {"build/initrd-threadapi.img"}
USER_UNITS=["thread.cpp","syllable_thread_probe.cpp","thread_runtime.c","tcb_bootstrap.c","thread_identity.c","semaphore.c","native_tcb_tls.S"]
def current_artifacts():
    value=locker.current_artifacts(); value["initrd"]=base.sha(ROOT/"build/initrd-threadapi.img")
    value.update({key:base.sha(ROOT/path) for key,path in NEW_FILES.items()}); return value
def verify_sources():
    p=module("threadapi_original_sources",ROOT/"scripts/prepare-syllable-thread.py")
    source=ROOT/"build/syllable-thread"; record=json.loads((source/"sources.json").read_text())
    expected=[{"path":path,"sha256":sha,"license":"LGPL-2.0-only"} for path,sha in p.FILES.items()]
    if record.get("files")!=expected or record.get("commit")!=p.REV or record.get("license")!="LGPL-2.0-only" or not record.get("sourceLicenseBasis"):
        raise RuntimeError("incorrect original Thread revision/license/source pins")
    for path,sha in p.FILES.items():
        if base.sha(source/"upstream"/path)!=sha: raise RuntimeError("modified original Thread input")
        if "/include/" in path and base.sha(source/"include"/path.split("/include/",1)[1])!=sha:
            raise RuntimeError("modified original Thread public header")
    if (record.get("patchSha256")!=base.sha(ROOT/"ports/syllable/patches/thread-rv32.patch") or
        record.get("adaptedThreadSha256")!=base.sha(source/"thread.cpp") or
        base.sha(source/"COPYING.LIB")!=base.sha(ROOT/"ports/syllable/COPYING.LIB")):
        raise RuntimeError("modified Thread patch/adapted source/license")
    locker.verify_prepared_sources(); return record
def validate_case(source,current,gate="C",full=True):
    if full: result,serial=locker.validate_case(source,current)
    else:
        result=json.loads((source/"result.json").read_text()); serial=(source/"serial.txt").read_text()
        if result.get("result")!="PASS" or result.get("baseIsa")!="rv32imac" or runner.guest_failure(serial):
            raise RuntimeError("incomplete progressive Thread run")
        for key in ("xnu","cbx","initrd",*NEW_FILES):
            if result.get("artifactSha256",{}).get(key)!=current[key]: raise RuntimeError("stale progressive Thread artifact")
        if "Bash exited status=0 and PID1 reaped PID2 PASS" not in serial: raise RuntimeError("missing actual Bash exit")
        for filename,digest in result.get("screenshots",{}).items():
            if Path(filename).name!=filename or Path(filename).suffix!=".png" or base.sha(source/filename)!=digest:
                raise RuntimeError("modified progressive scanout")
    required_scanouts={"00-shared-area.png","01-syllable.png","02-keyboard-focus.png",
                       "03-mouse-drag.png","04-input-verified.png","05-session-restart.png"}
    if full: required_scanouts.add("00-freetype-fonts.png")
    if result.get("resolution")!=[800,600] or not required_scanouts.issubset(result.get("screenshots",{})):
        raise RuntimeError("missing actual graphics/input scanout evidence")
    profile=result.get("syllableThread") or {}
    required={"gates":list("ABC"[:ord(gate)-ord("A")+1]),"cpu":0,"nativeClock":True,
      "source":"Syllable 579e480a005321cc320e7e355e8dff398b689be8 util/thread.cpp",
      "createdReaped":146 if gate>="C" else 18 if gate>="B" else 2,
      "cancelled":64 if gate>="C" else 0,"timerSleeps":640 if gate>="B" else 0,
      "finiteTimeoutCycles":64 if gate>="C" else 0,"appServerBuilt":False,"threadedLibcImplemented":False}
    if any(profile.get(k)!=v for k,v in required.items()): raise RuntimeError("incomplete or unsupported Thread profile")
    for name,contents in runner.validate_syllable_thread_log(serial,gate).items():
        if (source/name).read_text()!=contents: raise RuntimeError("Thread log differs from actual serial")
    return result,serial
def check_up_progressive(current):
    checked=[]
    for case,gate in zip(PROGRESSIVE,"AB"):
        source=ROOT/"build/graphics-tests"/case; result,serial=validate_case(source,current,gate,False)
        if result.get("smp")!=1 or result.get("bios")!="default": raise RuntimeError("wrong progressive platform")
        checked.append((case,source,result,serial))
    source=ROOT/"build/graphics-tests"/CASES[0]; result,serial=validate_case(source,current)
    if result.get("smp")!=1 or result.get("bios")!="default": raise RuntimeError("wrong full UP platform")
    checked.append((CASES[0],source,result,serial)); return checked
def validate_rebuild(record,current):
    rows=record.get("after",[])
    if (record.get("result")!="PASS" or record.get("before")!=rows or record.get("forcedKernelUnits")!=["native_thread"] or
        record.get("forcedUserUnits")!=USER_UNITS or len(rows)!=len(REBUILD_PATHS) or {row["path"] for row in rows}!=REBUILD_PATHS):
        raise RuntimeError("missing actual byte-identical Thread/kernel rebuild")
    for row in rows:
        digest=current["xnu"] if row["path"]=="xnu" else base.sha(ROOT/row["path"])
        if digest!=row["sha256"]: raise RuntimeError("stale Thread rebuild artifact")
def validate_process_regression(current):
    path=ROOT/"build/native-thread-process-regression.txt"; log=base.read_shell_log(path)
    completed=re.findall(r"^OK: (\S+)\r?$",log,re.M)
    expected={"boot_stage1",*(f"boot_stage1_process_gate_{i}"+("_only" if 7<=i<=10 else "") for i in range(2,16))}
    proof=json.loads((ROOT/"build/native-thread-process-regression.json").read_text(encoding="utf-8-sig"))
    if (len(completed)!=15 or set(completed)!=expected or "testproject.ps1 completed." not in log or
        proof.get("result")!="PASS" or proof.get("kernelBefore")!=current["xnu"] or proof.get("kernelAfter")!=current["xnu"] or
        proof.get("logSha256")!=base.sha(path) or set(proof.get("completedTargets",[]))!=expected):
        raise RuntimeError("missing fresh actual process regression for current kernel")
    return proof,completed
def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--check-up-progressive",action="store_true"); args=parser.parse_args()
    current=current_artifacts(); sources=verify_sources(); checked=check_up_progressive(current)
    if args.check_up_progressive:
        print("PASS current-hash actual Thread progressive A/B and full UP, source pins and serial/resource evidence"); return
    for case in (*CASES[1:],*REPEATS):
        source=ROOT/("build/graphics-tests" if case in CASES else "build")/case
        result,serial=validate_case(source,current)
        if result.get("smp")!=2 or (result.get("bios")=="default")!=(case!=CASES[2]): raise RuntimeError("Thread matrix platform mismatch")
        checked.append((case,source,result,serial))
    for case in OFF:
        source=ROOT/"build/graphics-tests"/case
        if case==OFF[0]:
            off_current=base.current_artifacts(); result,serial=base.validate_case(source,off_current,True)
        else:
            off_current=locker.tcb.futex.current_artifacts(); result,serial=locker.tcb.futex.validate_case(source,off_current,True)
        if result.get("smp")!=1 or result.get("bios")!="default" or runner.guest_failure(serial): raise RuntimeError("wrong default-off Thread platform")
        checked.append((case,source,result,serial))
    rebuild_path=ROOT/"build/threadapi-rebuild.json"; rebuild=json.loads(rebuild_path.read_text(encoding="utf-8-sig")); validate_rebuild(rebuild,current)
    if not re.search(r"^CC native_thread\.o\r?$",base.read_shell_log(ROOT/"build/threadapi-force-kernel.txt"),re.M): raise RuntimeError("missing actual kernel compilation log")
    log=base.read_shell_log(ROOT/"build/threadapi-force-probe.txt").replace("\\","/")
    for marker in ("build/syllable-thread/thread.cpp -o build/syllable_thread.o","userland/syllable_thread_probe.cpp -o build/syllable_thread_probe.o",
                   "ports/syllable/native/thread_runtime.c -o build/syllable_thread_runtime.o","-DCARIBE_SYNC_NATIVE_CLOCK","wrote build/initrd-threadapi.img:"):
        if marker not in log: raise RuntimeError("missing actual Thread/adapters/image rebuild log")
    proof,completed=validate_process_regression(current)
    host_path=ROOT/"build/threadapi-host-tests.txt"; host=base.read_shell_log(host_path); count=re.search(r"Ran (\d+) tests",host)
    if not count or int(count[1])<160 or not re.search(r"^OK\r?$",host,re.M) or "FAILED (" in host: raise RuntimeError("incomplete Thread host guards")
    musl=module("threadapi_musl",ROOT/"tools/verify-musl-tcb-source.py").verify_sources(ROOT)
    prior=json.loads((ROOT/"docs/evidence/syllable-locker-v0.12/manifest.json").read_text())
    for key,digest in prior["currentArtifactSha256"].items():
        if key=="xnu": continue
        now=base.sha(ROOT/"build/initrd-locker.img") if key=="initrd" else current.get(key)
        if digest!=now: raise RuntimeError(f"prior Locker dependency changed: {key}")
    old=ROOT/"build/last-stable-locker-v0.12/kernel.elf"
    if base.sha(old)!=prior["currentArtifactSha256"]["xnu"]: raise RuntimeError("prior stable kernel snapshot changed")
    # Promotion begins only after all fresh matrix, rebuild, process and source checks.
    records=[]
    for case,source,result,serial in checked:
        target=OUT/CASE_SLUGS[case]; target.mkdir(parents=True,exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix==".png" or path.name.startswith("gate-") or path.name=="result.json": shutil.copyfile(path,target/path.name)
        (target/"boot-summary.txt").write_text("\n".join(line for line in serial.splitlines() if line.startswith(("[smp-gate-","[boot-report]","[SecureSBI]","[process-gate-11]","[syllable-thread]")))+"\n")
        records.append({"case":case,"evidenceDirectory":CASE_SLUGS[case],"fullLocalSerialSha256":base.sha(source/"serial.txt"),"artifacts":result["artifactSha256"]})
    shutil.copyfile(rebuild_path,OUT/"rebuild.json")
    (OUT/"sources.json").write_text(json.dumps(sources,indent=2)+"\n")
    (OUT/"musl-sources.json").write_text(json.dumps(musl,indent=2)+"\n")
    (OUT/"process-regression.json").write_text(json.dumps(proof,indent=2)+"\n")
    (OUT/"process-regression.txt").write_text("PASS 15 actual runner targets, fresh for this kernel\n"+"\n".join("OK: "+target for target in completed)+"\n")
    (OUT/"host-guards.txt").write_text(f"PASS {count[1]} actual host unit tests; not guest proof\nFull local log SHA-256: {base.sha(host_path)}\n")
    (OUT/"manifest.json").write_text(json.dumps({"recorded":"2026-10-13","result":"PASS","cases":records,
      "scope":"genuine original Syllable Thread/native lifecycle/clock, CPU0; not Looper/AppServer or threaded libc",
      "currentArtifactSha256":current,"freshProcessRegression":True,"priorLockerDependenciesUnchangedExceptKernel":True},indent=2)+"\n")
    snapshot=ROOT/"build/last-stable-thread-v0.13"; snapshot.mkdir(parents=True,exist_ok=True)
    for name,source in {"kernel.elf":ROOT.parent.parent/"xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
                        "initrd-threadapi.img":ROOT/"build/initrd-threadapi.img","syllable-thread-probe.elf":ROOT/"build/syllable-thread-probe.elf"}.items():
        shutil.copyfile(source,snapshot/name)
        if base.sha(source)!=base.sha(snapshot/name): raise RuntimeError("Thread stable snapshot differs")
    print("PASS retained original Syllable Thread progressive/repeated UP/SMP/SecureSBI/default-off, fresh process regression and kernel rebuild; v0.12 preserved")
if __name__=="__main__": main()
