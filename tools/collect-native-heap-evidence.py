#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Promote genuine allocator/worker Message proof, not a desktop completion."""
import argparse
from datetime import date
import importlib.util
import json
from pathlib import Path
import re
import shutil
import tarfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/evidence/syllable-heap-v0.15"


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec); spec.loader.exec_module(value); return value


parent=module("heap_queue_evidence",ROOT/"tools/collect-syllable-queue-evidence.py")
base,runner=parent.base,parent.runner
SUFFIX=parent.SUFFIX.replace("queue-c-","queue-c-heap-c-")
CASES=tuple(f"{platform}-smp{cpus}-{SUFFIX}" for platform,cpus in (("opensbi",1),("opensbi",2),("securesbi",2)))
PROGRESSIVE=tuple(case.replace(f"queue-{g}-",f"queue-{g}-heap-{g}-") for case,g in zip(parent.PROGRESSIVE,"ab"))
REPEATS=("heap-smp-repeat-01","heap-smp-repeat-02")
OLD=parent.CASES[:2]
HEAP_OFF=OLD[0].replace("queue-c-","queue-c-heap-disabled-")
CASE_SLUGS=dict(zip((*PROGRESSIVE,*CASES,*REPEATS,*OLD,*parent.parent.OFF,HEAP_OFF),
    ("up-a","up-b","opensbi-up","opensbi-smp-final","securesbi-smp","smp-repeat-01","smp-repeat-02",
     "queue-up","queue-smp","threads-off","futex-off","heap-off")))
NEW_FILES={"nativeHeapProbe":"build/native-heap-probe.elf",
           "nativeHeapMusl":"build/musl-heap-rv32-sysroot/usr/lib/libc.a",
           "nativeHeapSources":"build/musl-heap-source/sources.json"}
REBUILD_PATHS=parent.REBUILD_PATHS|set(NEW_FILES.values())|{
    "build/initrd-heap.img","build/syllable_heap_runtime.o","build/native_heap_lock_probe.o","build/native_heap_probe.o"}
MUSL_UNITS=["malloc/mallocng/malloc.c","malloc/mallocng/free.c","malloc/mallocng/realloc.c","thread/__lock.c","mman/mmap.c","mman/munmap.c"]


def current_artifacts():
    current=parent.current_artifacts(); current["initrd"]=base.sha(ROOT/"build/initrd-heap.img")
    current.update({key:base.sha(ROOT/path) for key,path in NEW_FILES.items()}); return current


def verify_sources():
    parent.verify_sources()
    p=module("heap_musl_pins",ROOT/"scripts/prepare-musl-heap.py")
    source=ROOT/"build/musl-heap-source/musl-1.2.5"
    record=json.loads((source.parent/"sources.json").read_text())
    archive=ROOT/"third_party/musl-1.2.5.tar.gz"
    if base.sha(archive)!=p.ARCHIVE_SHA or record.get("archiveSha256")!=p.ARCHIVE_SHA or record.get("version")!="1.2.5":
        raise RuntimeError("incorrect musl heap archive/version")
    expected=[]
    with tarfile.open(archive,"r:gz") as upstream:
        for member in upstream.getmembers():
            if not member.isfile(): continue
            path=member.name.removeprefix("musl-1.2.5/"); data=upstream.extractfile(member).read()
            digest=p.sha(data); expected.append({"path":path,"sha256":digest})
            if path==p.ARCH_PATH:
                if digest!=p.ARCH_SHA or record.get("originalArchSha256")!=digest:
                    raise RuntimeError("modified original musl syscall header")
            elif (source/path).read_bytes()!=data:
                raise RuntimeError("modified genuine musl allocator/lock/source input")
            if path=="COPYRIGHT" and (ROOT/"ports/musl/COPYRIGHT").read_bytes()!=data:
                raise RuntimeError("modified distributed original musl notices")
    if record.get("originalInputs")!=expected or len(expected)!=2697 or record.get("license")!="MIT; complete original musl COPYRIGHT unchanged":
        raise RuntimeError("incomplete original musl source/license record")
    if record.get("patchSha256")!=base.sha(ROOT/"ports/musl/patches/native-heap-rv32.patch") or record.get("adaptedArchSha256")!=base.sha(source/p.ARCH_PATH):
        raise RuntimeError("modified musl heap routing patch/header")
    return record


def validate_case(source,current,gate="C",full=True,disabled=False):
    result,serial=parent.validate_case(source,current,gate,full)
    for key in NEW_FILES:
        if result.get("artifactSha256",{}).get(key)!=current[key]: raise RuntimeError("stale native heap artifact")
    required={"gates":["off"] if disabled else list("ABC"[:ord(gate)-ord("A")+1]),"enabled":not disabled,
              "muslVersion":"1.2.5","cpu":0,"allocatorReplaced":False,"stdioEnabled":False,"pthreadImplemented":False,"appServerBuilt":False}
    if any((result.get("nativeHeap") or {}).get(k)!=v for k,v in required.items()):
        raise RuntimeError("incomplete or unsupported heap profile")
    for name,text in runner.validate_heap_log(serial,gate,disabled).items():
        if (source/name).read_text()!=text: raise RuntimeError("heap gate log differs from actual serial")
    return result,serial


def check_up_progressive(current):
    checked=[]
    for case,gate in zip(PROGRESSIVE,"AB"):
        source=ROOT/"build/graphics-tests"/case; result,serial=validate_case(source,current,gate,False)
        if result.get("smp")!=1 or result.get("bios")!="default": raise RuntimeError("wrong progressive heap platform")
        checked.append((case,source,result,serial))
    source=ROOT/"build/graphics-tests"/CASES[0]; result,serial=validate_case(source,current)
    if result.get("smp")!=1 or result.get("bios")!="default": raise RuntimeError("wrong full UP heap platform")
    checked.append((CASES[0],source,result,serial)); return checked


def validate_rebuild(record,current):
    rows=record.get("after",[])
    if (record.get("result")!="PASS" or record.get("before")!=rows or
        record.get("forcedKernelUnits")!=["native_thread","linux_syscall","syscall"] or record.get("forcedMuslUnits")!=MUSL_UNITS or
        record.get("forcedUserUnits")!=["native_heap_probe.cpp","native_heap_lock_probe.c","heap_runtime.c"] or
        record.get("priorQueueArtifactsUnchangedExceptKernel") is not True or len(rows)!=len(REBUILD_PATHS) or {r["path"] for r in rows}!=REBUILD_PATHS):
        raise RuntimeError("missing actual byte-identical kernel/musl/heap rebuild")
    for row in rows:
        digest=current["xnu"] if row["path"]=="xnu" else base.sha(ROOT/row["path"])
        if row["sha256"]!=digest: raise RuntimeError("stale heap rebuild artifact")


def validate_previous():
    prior=json.loads((ROOT/"docs/evidence/syllable-queue-v0.14/rebuild.json").read_text())
    for row in prior["after"]:
        path=ROOT/"build/last-stable-queue-v0.14/kernel.elf" if row["path"]=="xnu" else ROOT/row["path"]
        if base.sha(path)!=row["sha256"]: raise RuntimeError("prior stable Queue artifact changed")


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--check-up-progressive",action="store_true"); args=parser.parse_args()
    current=current_artifacts(); sources=verify_sources(); checked=check_up_progressive(current); validate_previous()
    if args.check_up_progressive:
        print("PASS actual current-hash heap A/B and full UP, genuine musl inputs and unchanged v0.14 userland"); return
    for case in (*CASES[1:],*REPEATS):
        source=ROOT/("build/graphics-tests" if case in CASES else "build")/case
        result,serial=validate_case(source,current)
        if result.get("smp")!=2 or (result.get("bios")=="default")!=(case!=CASES[2]): raise RuntimeError("wrong heap SMP/firmware platform")
        checked.append((case,source,result,serial))
    for case,smp in zip(OLD,(1,2)):
        source=ROOT/"build/graphics-tests"/case; result,serial=parent.validate_case(source,parent.current_artifacts())
        if result.get("smp")!=smp or result.get("bios")!="default" or result.get("nativeHeap") is not None: raise RuntimeError("wrong preserved Queue profile")
        checked.append((case,source,result,serial))
    for case in parent.parent.OFF:
        source=ROOT/"build/graphics-tests"/case
        if case==parent.parent.OFF[0]: result,serial=base.validate_case(source,base.current_artifacts(),True)
        else:
            futex=parent.parent.locker.tcb.futex
            result,serial=futex.validate_case(source,futex.current_artifacts(),True)
        if result.get("smp")!=1 or result.get("bios")!="default" or runner.guest_failure(serial): raise RuntimeError("wrong default-off dependency profile")
        checked.append((case,source,result,serial))
    source=ROOT/"build/graphics-tests"/HEAP_OFF; result,serial=validate_case(source,current,disabled=True)
    if result.get("smp")!=1 or result.get("bios")!="default": raise RuntimeError("wrong disabled heap platform")
    checked.append((HEAP_OFF,source,result,serial))
    rebuild_path=ROOT/"build/heap-rebuild.json"; rebuild=json.loads(rebuild_path.read_text(encoding="utf-8-sig")); validate_rebuild(rebuild,current)
    for unit in ("native_thread","linux_syscall","syscall"):
        if not re.search(rf"^CC {unit}\.o\r?$",base.read_shell_log(ROOT/"build/heap-force-kernel.txt"),re.M): raise RuntimeError("missing actual heap kernel compilation log")
    musl_log=base.read_shell_log(ROOT/"build/heap-force-musl.txt").replace("\\","/")
    for unit in MUSL_UNITS:
        if "src/"+unit not in musl_log: raise RuntimeError("missing actual genuine musl compile log")
    user_log=base.read_shell_log(ROOT/"build/heap-force-probe.txt").replace("\\","/")
    for marker in ("userland/native_heap_probe.cpp -o build/native_heap_probe.o","ports/syllable/native/heap_runtime.c -o build/syllable_heap_runtime.o","wrote build/initrd-heap.img:"):
        if marker not in user_log: raise RuntimeError("missing actual heap integration/image rebuild log")
    proof,completed=parent.parent.validate_process_regression(current)
    host_path=ROOT/"build/heap-host-tests.txt"; host=base.read_shell_log(host_path); count=re.search(r"Ran (\d+) tests",host)
    if not count or int(count[1])<245 or not re.search(r"^OK\r?$",host,re.M) or "FAILED (" in host: raise RuntimeError("incomplete heap host guards")
    # Retention starts only after every current-hash runtime, source and rebuild gate.
    records=[]
    for case,source,result,serial in checked:
        target=OUT/CASE_SLUGS[case]; target.mkdir(parents=True,exist_ok=True)
        for path in sorted(source.iterdir()):
            if path.suffix==".png" or path.name.startswith("gate-") or path.name=="result.json": shutil.copyfile(path,target/path.name)
        (target/"boot-summary.txt").write_text("\n".join(l for l in serial.splitlines() if l.startswith(
            ("[smp-gate-","[boot-report]","[SecureSBI]","[process-gate-11]","[native-heap]")))+"\n")
        records.append({"case":case,"evidenceDirectory":CASE_SLUGS[case],"fullLocalSerialSha256":base.sha(source/"serial.txt"),"artifacts":result["artifactSha256"]})
    shutil.copyfile(rebuild_path,OUT/"rebuild.json")
    (OUT/"musl-sources.json").write_text(json.dumps(sources,indent=2)+"\n")
    (OUT/"process-regression.json").write_text(json.dumps(proof,indent=2)+"\n")
    (OUT/"process-regression.txt").write_text("PASS 15 fresh actual runner targets\n"+"\n".join("OK: "+t for t in completed)+"\n")
    (OUT/"host-guards.txt").write_text(f"PASS {count[1]} host tests, not guest proof\nLocal log SHA-256: {base.sha(host_path)}\n")
    (OUT/"manifest.json").write_text(json.dumps({"recorded":str(date.today()),"result":"PASS","cases":records,
        "scope":"genuine musl allocator and worker Message/ReadPort, CPU0; not pthread/GNU exceptions or Looper/AppServer",
        "currentArtifactSha256":current,"freshProcessRegression":True,"priorQueueArtifactsUnchangedExceptKernel":True},indent=2)+"\n")
    snapshot=ROOT/"build/last-stable-heap-v0.15"; snapshot.mkdir(parents=True,exist_ok=True)
    for name,source in {"kernel.elf":ROOT.parent.parent/"xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
                         "initrd-heap.img":ROOT/"build/initrd-heap.img","native-heap-probe.elf":ROOT/"build/native-heap-probe.elf"}.items():
        shutil.copyfile(source,snapshot/name)
        if base.sha(source)!=base.sha(snapshot/name): raise RuntimeError("heap snapshot differs")
    print("PASS retained genuine allocator/worker Message/ReadPort, critical owner cleanup and full actual matrix/rebuild; v0.14 preserved")


if __name__=="__main__": main()
