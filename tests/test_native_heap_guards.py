# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host validator/source fixtures, never substituted for real allocator gates."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec); spec.loader.exec_module(value); return value


runner=module("heap_runner_guards",ROOT/"scripts/test-graphics.py")


class HeapGuards(unittest.TestCase):
    def setUp(self):
        self.text=("HOST ONLY FIXTURE NOT A BOOT\n"
          "[native-heap-gate-A] genuine musl VM; anonymous RW only; execute/file/PROT_NONE/mremap unsupported; stacks/TCB protected; Linux worker VM/FD denied PASS\n"
          "[native-heap-gate-B] workers=16 calloc/realloc/aligned/free cycles=160000 genuine worker Message decode/Queue cycles=10000 independent TCBs cpu=0 PASS\n"
          "[native-heap-gate-C] genuine worker ReadPort typed messages=10000; actual allocator futex cancellations=64 unreturned results freed=64; critical faults=8 owner exits=8 whole-process cleanup PASS\n"
          "[native-heap] created=reaped=163 cancelled=72 expected-faults=8 aborted-scopes=16 active=0 waiters=0 pool released PASS\n"
          "[native-heap] gates A-C PASS; genuine musl allocator and worker Message, not pthread/GNU exceptions or Looper/AppServer\n")
    def reject(self,old,new):
        with self.assertRaises(RuntimeError): runner.validate_heap_log(self.text.replace(old,new),"C")
    def test_host_fixture(self): self.assertEqual(len(runner.validate_heap_log(self.text,"C")),3)
    def test_missing_gate(self): self.reject("[native-heap-gate-B]","absent")
    def test_worker_count(self): self.reject("workers=16","workers=15")
    def test_partial_allocator(self): self.reject("cycles=160000","cycles=159999")
    def test_partial_Message(self): self.reject("cycles=10000","cycles=9999")
    def test_wrong_cpu(self): self.reject("cpu=0","cpu=1")
    def test_missing_ReadPort(self): self.reject("typed messages=10000","typed messages=9999")
    def test_partial_cancellation(self): self.reject("cancellations=64","cancellations=63")
    def test_leaked_unreturned_result(self): self.reject("freed=64","freed=63")
    def test_partial_faults(self): self.reject("critical faults=8","critical faults=7")
    def test_partial_owner_exit(self): self.reject("owner exits=8","owner exits=7")
    def test_partial_reaping(self): self.reject("created=reaped=163","created=reaped=162")
    def test_wrong_cancel_counter(self): self.reject("cancelled=72","cancelled=71")
    def test_unexpected_fault_counter(self): self.reject("expected-faults=8","expected-faults=9")
    def test_abandoned_scope_counter(self): self.reject("aborted-scopes=16","aborted-scopes=15")
    def test_active_scope_leak(self): self.reject("active=0","active=1")
    def test_waiter_leak(self): self.reject("waiters=0","waiters=1")
    def test_false_complete_claim(self): self.reject("not pthread/GNU exceptions or Looper/AppServer","AppServer complete")
    def test_failed_guest_after_pass(self):
        with self.assertRaises(RuntimeError): runner.validate_heap_log(self.text+"[native-heap] FAIL allocator\n","C")
    def test_disabled_profile_fixture(self):
        text="[native-heap] disabled profile VM=ENOTSUP allocator activation denied; default musl and worker boundary unchanged PASS"
        self.assertEqual(len(runner.validate_heap_log(text,"C",True)),1)
        with self.assertRaises(RuntimeError): runner.validate_heap_log(text.replace("ENOTSUP","success"),"C",True)
    def test_pinned_original_allocator_not_replaced(self):
        p=module("heap_source_pins",ROOT/"scripts/prepare-musl-heap.py")
        self.assertEqual(p.ARCHIVE_SHA,"a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4")
        text=(ROOT/"ports/musl/patches/native-heap-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: MIT",text); self.assertNotIn("BSD-2-Clause",text)
        self.assertNotIn("src/malloc",text); self.assertNotIn("src/thread/__lock",text)
    def test_changed_archive_rejected_before_extraction(self):
        p=module("heap_bad_archive",ROOT/"scripts/prepare-musl-heap.py")
        with tempfile.TemporaryDirectory(dir=ROOT/"build",prefix="heap-host-") as directory:
            root=Path(directory); archive=root/"third_party/musl-1.2.5.tar.gz"
            archive.parent.mkdir(); archive.write_bytes(b"HOST TAMPERED ARCHIVE")
            with patch.object(p,"ROOT",root),patch.object(p,"OUT",root/"build"),patch.object(p.tarfile,"open") as extraction:
                with self.assertRaisesRegex(RuntimeError,"pinned"): p.main()
                extraction.assert_not_called()
    def test_real_functions_and_need_locks(self):
        text=(ROOT/"ports/syllable/native/heap_runtime.c").read_text()
        for token in ("__real_malloc", "__real_calloc", "__real_realloc", "__real_free", "libc.need_locks,1", "scope(CARIBE_THREAD_HEAP_LEAVE,0)"):
            self.assertIn(token,text)
        self.assertNotIn("libc.threaded=1",text)
        self.assertLess(text.index("__real_free(p);",text.index("static void finish_result")),text.index("(void)caribe_heap_scope_leave();",text.index("static void finish_result")))
    def test_separate_libc_and_initrd(self):
        text=(ROOT/"Makefile").read_text()
        self.assertIn("HEAP_SYSROOT = build/musl-heap-rv32-sysroot",text)
        self.assertIn("build/initrd-heap.img: build/initrd-queue.img",text)
        self.assertIn("CARIBE_MUSL_SYSROOT=$(CURDIR)/$(HEAP_SYSROOT)",text)
        self.assertIn("--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=free",text)
    def test_guest_uses_actual_classes_lock_and_blocked_waiter(self):
        text=(ROOT/"userland/native_heap_probe.cpp").read_text()
        for token in ("os::MessageQueue q", "message.ReadPort(input)", "decoded.Unflatten", "CARIBE_THREAD_HEAP_WAITERS", "worker.WaitFor()", "victim.Terminate()", "partial_stack+16"):
            self.assertIn(token,text)
        self.assertIn("__lock(__malloc_lock)",(ROOT/"userland/native_heap_lock_probe.c").read_text())
    def test_worker_no_stdio_or_pthread(self):
        text=(ROOT/"userland/native_heap_probe.cpp").read_text().split("int32 Run() override",1)[1].split("static void partial_entry",1)[0]
        for token in ("printf(","puts(","pthread_create(","throw "):
            self.assertNotIn(token,text)
    def test_disabled_dependencies_rejected_early(self):
        for option in ("--native-heap-disabled","--native-threads-disabled","--native-futex-disabled"):
            result=subprocess.run([sys.executable,str(ROOT/"scripts/test-graphics.py"),"--native-heap",option],capture_output=True,text=True)
            self.assertEqual(result.returncode,2); self.assertIn("heap gates require enabled",result.stderr)
    def test_public_mode_rejected_before_build(self):
        result=subprocess.run(["powershell","-NoProfile","-File",str(ROOT/"testproject.ps1"),"-Mode","up","-SyllableHeap"],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0); self.assertIn("Heap gates are supported",result.stderr)
        self.assertIn("-SyllableHeap:$SyllableHeap -DisableNativeHeap:$DisableNativeHeap -HeapGate $HeapGate",(ROOT/"testproject.ps1").read_text())
    def test_boot_optin_not_default(self):
        self.assertIn('("native-heap " if args.native_heap else "")',(ROOT/"scripts/test-graphics.py").read_text())
    def test_paired_kernel_protects_rounded_stack_and_defers_cancel(self):
        path=ROOT.parent.parent/"xnu-2050.48.11/osfmk/riscv32"
        if not path.exists(): self.skipTest("paired kernel required")
        text=(path/"linux_syscall.c").read_text()
        self.assertIn("riscv32_linux_page_up(length)",text)
        self.assertIn("number, boolean_t native",text)
        self.assertIn("flags != (RISCV32_LINUX_MAP_PRIVATE | RISCV32_LINUX_MAP_ANONYMOUS)",text)
        native=(path/"native_thread.c").read_text()
        self.assertIn("object->heap_depth == 1U && object->cancel_pending && !arg.status",native)
        self.assertIn("RISCV32_LINUX_PROCESS_FLAG_HEAP_POISONED",native)
        self.assertIn("riscv32_linux_terminate_current(0U, 11U)",native)
        self.assertIn("object->cancel_deadline = nt_deadline(5000000U)",native)
    def test_qmp_temp_path_short_unique_and_owned(self):
        path=runner.qmp_capture_path("heap-long-case-"+"x"*160,"05-session-restart")
        self.assertEqual(path.parent,ROOT/"build")
        self.assertLess(len(str(path)),240)
        self.assertNotEqual(path,runner.qmp_capture_path("different-case","05-session-restart"))
        with self.assertRaises(ValueError): runner.qmp_capture_path("case","../../outside")
    def test_paired_cross_hart_gate_records_use_one_console_write(self):
        path=ROOT.parent.parent/"xnu-2050.48.11/osfmk/riscv32/linux_syscall.c"
        if not path.exists(): self.skipTest("paired kernel required")
        text=path.read_text()
        for marker in ("waitid job-control options=0x%08x", "exec argv/env collected argc=%u envc=%u"):
            position=text.index(marker)
            block=text[text.rfind("char record[",0,position):text.index("\n\t}",position)]
            self.assertEqual(block.count("riscv32_early_puts("),1)
            self.assertIn("riscv32_early_puts(record);",block)
            self.assertNotIn("riscv32_early_putdec(",block)
            self.assertNotIn("riscv32_early_puthex32(",block)


class HeapEvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.c=module("heap_evidence_guard",ROOT/"tools/collect-native-heap-evidence.py")
        self.digest="a"*64
        rows=[{"path":path,"sha256":self.digest} for path in sorted(self.c.REBUILD_PATHS)]
        self.record={"result":"PASS","before":rows,"after":rows,"forcedKernelUnits":["native_thread","linux_syscall","syscall"],
            "forcedMuslUnits":self.c.MUSL_UNITS[:],"forcedUserUnits":["native_heap_probe.cpp","native_heap_lock_probe.c","heap_runtime.c"],
            "priorQueueArtifactsUnchangedExceptKernel":True}
    def validate(self):
        with patch.object(self.c.base,"sha",return_value=self.digest): self.c.validate_rebuild(self.record,{"xnu":self.digest})
    def test_consistent_host_rebuild_fixture(self): self.validate()
    def test_missing_kernel_unit(self):
        self.record["forcedKernelUnits"]=["native_thread"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_missing_genuine_musl_lock(self):
        self.record["forcedMuslUnits"].remove("thread/__lock.c")
        with self.assertRaises(RuntimeError): self.validate()
    def test_compile_inputs_use_actual_mallocng_source_paths(self):
        force=(ROOT/"scripts/test-musl-heap-force.sh").read_text()
        rebuild=(ROOT/"scripts/test-native-heap-rebuild.ps1").read_text()
        for unit in self.c.MUSL_UNITS:
            self.assertIn("src/"+unit,force)
            self.assertIn("'"+unit+"'",rebuild)
    def test_missing_libc_artifact(self):
        self.record["after"]=[r for r in self.record["after"] if r["path"]!="build/musl-heap-rv32-sysroot/usr/lib/libc.a"]
        self.record["before"]=self.record["after"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_stale_kernel_rejected(self):
        with patch.object(self.c.base,"sha",return_value=self.digest):
            with self.assertRaises(RuntimeError): self.c.validate_rebuild(self.record,{"xnu":"b"*64})
    def test_previous_preservation_required(self):
        self.record["priorQueueArtifactsUnchangedExceptKernel"]=False
        with self.assertRaises(RuntimeError): self.validate()
    def test_short_distinct_retained_paths(self):
        self.assertEqual(len(self.c.CASE_SLUGS),12); self.assertEqual(len(set(self.c.CASE_SLUGS.values())),12)
        for slug in self.c.CASE_SLUGS.values():
            self.assertLess(len(slug),24); self.assertNotIn("/",slug); self.assertNotIn("..",slug)
    def test_no_retention_before_fresh_process_regression(self):
        text=(ROOT/"tools/collect-native-heap-evidence.py").read_text()
        self.assertLess(text.index("parent.parent.validate_process_regression(current)"),text.index("# Retention starts"))


if __name__=="__main__": unittest.main()
