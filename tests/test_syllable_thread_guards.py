# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host-only source/validator fixtures; never evidence of actual guest threads."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec); spec.loader.exec_module(value); return value
runner=module("threadapi_runner",ROOT/"scripts/test-graphics.py")
class ThreadGuards(unittest.TestCase):
    def setUp(self):
        self.text=("HOST ONLY FIXTURE NOT A BOOT\n"
          "[syllable-thread-gate-A] original os::Thread and C lifecycle; suspended/resume/join status=0x12345678; 64-bit native clock; unsupported errors PASS\n"
          "[syllable-thread-gate-B] workers=16 rounds=160000 recursive acquisitions=320000 overlaps=0 cpu=0 sleeps=640 timer-waits=640 scheduler-waits=100 PASS\n"
          "[syllable-thread-gate-C] finite timeout cycles=64 elapsed>=2000us native-timeouts=64; sleep cancellation cycles=64; original Initialize/Terminate and generic reaping PASS\n"
          "[syllable-thread] created=reaped=146 cancelled=64 live=0 semaphores=0 pool released PASS\n"
          "[syllable-thread] gates A-C PASS; genuine Syllable Thread/native clock, not Looper/AppServer or threaded libc\n")
    def reject(self,old,new):
        with self.assertRaises(RuntimeError): runner.validate_syllable_thread_log(self.text.replace(old,new),"C")
    def test_host_fixture(self): self.assertEqual(len(runner.validate_syllable_thread_log(self.text,"C")),3)
    def test_missing_gate(self): self.reject("[syllable-thread-gate-B]","absent")
    def test_partial_stress(self): self.reject("rounds=160000","rounds=159999")
    def test_partial_recursion(self): self.reject("acquisitions=320000","acquisitions=319999")
    def test_wrong_cpu(self): self.reject("cpu=0","cpu=1")
    def test_overlapping_owners(self): self.reject("overlaps=0","overlaps=1")
    def test_no_timer_waits(self): self.reject("timer-waits=640","timer-waits=0")
    def test_partial_timer_waits(self): self.reject("timer-waits=640","timer-waits=639")
    def test_no_contention(self): self.reject("scheduler-waits=100","scheduler-waits=0")
    def test_partial_timeouts(self): self.reject("native-timeouts=64","native-timeouts=63")
    def test_partial_cancel_cycles(self): self.reject("cancellation cycles=64","cancellation cycles=63")
    def test_partial_reaping(self): self.reject("created=reaped=146","created=reaped=145")
    def test_wrong_cancel_count(self): self.reject("cancelled=64","cancelled=63")
    def test_leaked_resources(self): self.reject("live=0 semaphores=0","live=1 semaphores=1")
    def test_failed_guest_after_pass(self):
        with self.assertRaises(RuntimeError): runner.validate_syllable_thread_log(self.text+"[syllable-thread] FAIL owner\n","C")
    def test_false_complete_claim(self): self.reject("not Looper/AppServer or threaded libc","AppServer complete")
    def test_genuine_class_not_reimplemented(self):
        s=(ROOT/"userland/syllable_thread_probe.cpp").read_text()
        self.assertIn("#include <util/thread.h>",s); self.assertIn("public os::Thread",s)
        self.assertIn("thread.Initialize(",s); self.assertIn("thread.Terminate()",s)
        self.assertNotIn("class Thread {",s)
    def test_worker_does_not_use_threaded_libc(self):
        s=(ROOT/"userland/syllable_thread_probe.cpp").read_text().split("int32 Run() override",1)[1].split("static void gate_a()",1)[0]
        for token in ("printf(","puts(","malloc(","mmap(","new ","throw ","pthread_create("): self.assertNotIn(token,s)
    def test_thread_control_is_controller_only(self):
        s=(ROOT/"ports/syllable/native/thread_runtime.c").read_text()
        self.assertIn("r.id!=controller || r.owner!=owner || r.cpu",s)
        self.assertIn("r.id!=r.owner",s); self.assertIn("if (slots[i].id) { errno=EBUSY",s)
        self.assertIn("if (is_controller() || find_slot(id)<0)",s)
        self.assertIn("if (result<0 || r.state!=CARIBE_THREAD_EXITED)",s)
    def test_old_archives_remain_separate(self):
        s=(ROOT/"Makefile").read_text()
        old=s.split("build/libcaribe-syllable-locker.a:",1)[1].split("\n\n",1)[0]
        self.assertNotIn("syllable_thread_semaphore",old)
        self.assertIn("-DCARIBE_SYNC_RAW_TCB -DCARIBE_SYNC_NATIVE_CLOCK",s)
        self.assertIn("build/initrd-threadapi.img: build/initrd-locker.img",s)
    def test_no_process_kill_in_lgpl_patch(self):
        s=(ROOT/"ports/syllable/patches/thread-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only",s); self.assertNotIn("BSD-2-Clause",s)
        additions="\n".join(l for l in s.splitlines() if l.startswith("+") and not l.startswith("+++"))
        self.assertNotIn("kill(",additions); self.assertIn("caribe_syllable_thread_terminate",additions)
        self.assertIn("m_iThread = -1",additions)
    def test_source_pins_and_component_license_basis(self):
        p=module("threadapi_pins",ROOT/"scripts/prepare-syllable-thread.py")
        self.assertEqual(p.REV,"579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(p.FILES["system/sys/appserver/libsyllable/util/thread.cpp"],"048bfc2c8faec1e900799e90c41a51ea9a5437bb23d415992544f25632a591e5")
        self.assertIn("sourceLicenseBasis",(ROOT/"scripts/prepare-syllable-thread.py").read_text())
    def test_changed_source_fails_before_patch(self):
        p=module("threadapi_changed_source",ROOT/"scripts/prepare-syllable-thread.py")
        with tempfile.TemporaryDirectory(dir=ROOT/"build",prefix="threadapi-host-") as directory:
            root=Path(directory); file=root/"third_party/syllable/system/sys/appserver/libsyllable/util/thread.cpp"
            file.parent.mkdir(parents=True); file.write_text("HOST MODIFIED SOURCE\n")
            with patch.object(p,"ROOT",root),patch.object(p,"OUT",root/"build"),patch.object(p,"urlopen") as network,patch.object(p.subprocess,"run") as apply:
                with self.assertRaisesRegex(RuntimeError,"hash mismatch"): p.main()
                network.assert_not_called(); apply.assert_not_called()
    def test_public_runner_forwards_both_options(self):
        s=(ROOT/"testproject.ps1").read_text()
        self.assertIn("-SyllableThread:$SyllableThread -SyllableThreadGate $SyllableThreadGate",s)
        self.assertLess(s.index("Syllable Thread gates are supported"),s.index("$kernelElf ="))
    def test_fixed_wire_abi_and_operation_output(self):
        s=(ROOT/"include/uapi/caribe_thread.h").read_text()
        self.assertIn("sizeof(struct caribe_thread_request) == 128",s)
        self.assertIn("CARIBE_THREAD_CLOCK 10U",s); self.assertIn("CARIBE_THREAD_SLEEP 11U",s)
        self.assertIn("reserved[10]",s); self.assertIn("zero on input",s)
    def test_clock_and_sleep_do_not_change_linux_process_model(self):
        path=ROOT.parent.parent/"xnu-2050.48.11/osfmk/riscv32/native_thread.c"
        if not path.exists(): self.skipTest("paired kernel required for this cross-repository guard")
        s=path.read_text()
        self.assertIn("absolutetime_to_nanoseconds(mach_absolute_time(), &now)",s)
        self.assertIn("if (!object || !riscv32_native_thread_cpu_allowed()) return NT_PERM",s)
        self.assertIn("nt_wait_counted(&object->sequence, sequence, deadline, &sleep_waits)",s)
        worker=s.split("if (nt_current() && arg.operation",1)[1].split("return NT_NOTSUP",1)[0]
        self.assertIn("CARIBE_THREAD_CLOCK",worker); self.assertIn("CARIBE_THREAD_SLEEP",worker)
        for op in ("CREATE","START","CANCEL","JOIN"): self.assertNotIn("CARIBE_THREAD_"+op,worker)
    def test_rebuild_requires_actual_kernel_compile(self):
        s=(ROOT/"scripts/test-syllable-thread-rebuild.ps1").read_text()
        self.assertIn("-ForceRiscv32Sources native_thread",s)
        self.assertIn("CC native_thread\\.o",s)
        self.assertIn("build/syllable-thread/thread.cpp -o build/syllable_thread.o",s)
        self.assertIn("-W build/syllable-thread/sources.json",s)
    def test_collector_requires_fresh_process_regression(self):
        s=(ROOT/"tools/collect-syllable-thread-evidence.py").read_text()
        self.assertIn('proof.get("kernelBefore")!=current["xnu"]',s)
        self.assertIn('proof.get("logSha256")!=base.sha(path)',s)
        self.assertNotIn("validate_unchanged_kernel_baseline(current)",s)
        self.assertLess(s.index("validate_process_regression(current)\n"),s.index("# Promotion begins"))
class ThreadEvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.c=module("threadapi_evidence_guard",ROOT/"tools/collect-syllable-thread-evidence.py")
        self.digest="a"*64
        rows=[{"path":path,"sha256":self.digest} for path in sorted(self.c.REBUILD_PATHS)]
        self.record={"result":"PASS","before":rows,"after":rows,"forcedKernelUnits":["native_thread"],"forcedUserUnits":self.c.USER_UNITS[:]}
        self.current={"xnu":self.digest}
    def validate(self):
        with patch.object(self.c.base,"sha",return_value=self.digest): self.c.validate_rebuild(self.record,self.current)
    def test_consistent_host_rebuild_fixture(self): self.validate()
    def test_no_actual_kernel_unit_rejected(self):
        self.record["forcedKernelUnits"]=[]
        with self.assertRaises(RuntimeError): self.validate()
    def test_missing_native_source_unit_rejected(self):
        self.record["forcedUserUnits"]=self.record["forcedUserUnits"][:-1]
        with self.assertRaises(RuntimeError): self.validate()
    def test_missing_rebuild_artifact_rejected(self):
        self.record["after"]=self.record["after"][:-1]; self.record["before"]=self.record["after"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_duplicate_artifact_rejected(self):
        self.record["after"]=self.record["after"][:-1]+[self.record["after"][0]]; self.record["before"]=self.record["after"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_stale_kernel_hash_rejected(self):
        self.current["xnu"]="b"*64
        with self.assertRaises(RuntimeError): self.validate()
    def test_no_promotion_before_current_hash_up_checks(self):
        s=(ROOT/"tools/collect-syllable-thread-evidence.py").read_text()
        self.assertLess(s.index("checked=check_up_progressive(current)"),s.index("# Promotion begins"))
        self.assertIn('raise RuntimeError("stale progressive Thread artifact")',s)
    def test_scanouts_required_not_just_optional_hashes(self):
        s=(ROOT/"tools/collect-syllable-thread-evidence.py").read_text()
        self.assertIn('required_scanouts.add("00-freetype-fonts.png")',s)
        self.assertIn('required_scanouts.issubset(result.get("screenshots",{}))',s)
    def test_retained_evidence_paths_fit_windows(self):
        self.assertEqual(set(self.c.CASE_SLUGS),set((*self.c.PROGRESSIVE,*self.c.CASES,*self.c.REPEATS,*self.c.OFF)))
        self.assertEqual(len(set(self.c.CASE_SLUGS.values())),9)
        for slug in self.c.CASE_SLUGS.values():
            self.assertLess(len(slug),24)
            self.assertNotIn("/",slug); self.assertNotIn("..",slug)
if __name__=="__main__": unittest.main()
