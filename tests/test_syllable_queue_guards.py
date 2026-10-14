# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Host validator/source fixtures, not proof that a guest port or GUI ran."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


runner = module("queue_runner", ROOT / "scripts/test-graphics.py")


class QueueGuards(unittest.TestCase):
    def setUp(self):
        self.text = ("HOST ONLY FIXTURE NOT A BOOT\n"
                     "[syllable-queue-gate-A] original MessageQueue FIFO/search/remove/destructor; tail reuse cycles=100; native IPC guards PASS\n"
                     "[syllable-queue-gate-B] workers=16 original Queue/typed Message cycles=160000 overlaps=0 cpu=0 independent TCBs; controller-only allocation PASS\n"
                     "[syllable-queue-gate-C] native worker ping-pong=10000 max-payload=8192; finite timeouts=64 elapsed>=2000us; stale waiters=16 cancelled readers/writers=64; waits=wakeups=20145 resources restored PASS\n"
                     "[syllable-queue] created=reaped=161 cancelled=64 live=0 ports/messages/semaphores restored pool released PASS\n"
                     "[syllable-queue] gates A-C PASS; genuine MessageQueue/native worker ports, not Looper/AppServer or threaded libc\n")

    def reject(self, old, new):
        with self.assertRaises(RuntimeError):
            runner.validate_queue_log(self.text.replace(old, new), "C")

    def test_host_fixture(self):
        self.assertEqual(len(runner.validate_queue_log(self.text, "C")), 3)

    def test_missing_gate(self): self.reject("[syllable-queue-gate-B]", "absent")
    def test_partial_tail_reuse(self): self.reject("cycles=100;", "cycles=99;")
    def test_partial_queue_stress(self): self.reject("cycles=160000", "cycles=159999")
    def test_wrong_cpu(self): self.reject("cpu=0", "cpu=1")
    def test_overlap(self): self.reject("overlaps=0", "overlaps=1")
    def test_partial_pingpong(self): self.reject("ping-pong=10000", "ping-pong=9999")
    def test_partial_payload(self): self.reject("max-payload=8192", "max-payload=4096")
    def test_partial_timeouts(self): self.reject("timeouts=64", "timeouts=63")
    def test_short_deadline(self): self.reject("elapsed>=2000us", "elapsed>=1000us")
    def test_stale_waiter_missing(self): self.reject("stale waiters=16", "stale waiters=15")
    def test_partial_cancellation(self): self.reject("readers/writers=64", "readers/writers=63")
    def test_no_actual_wait(self): self.reject("waits=wakeups=20145", "waits=wakeups=0")
    def test_missing_registered_waits(self): self.reject("waits=wakeups=20145", "waits=wakeups=80")
    def test_partial_reaping(self): self.reject("created=reaped=161", "created=reaped=160")
    def test_leaked_workers(self): self.reject("live=0", "live=1")
    def test_failed_guest_after_pass(self):
        with self.assertRaises(RuntimeError):
            runner.validate_queue_log(self.text+"[syllable-queue] FAIL owner\n", "C")
    def test_false_complete_claim(self): self.reject("not Looper/AppServer or threaded libc", "AppServer complete")

    def test_original_source_pins_and_lgpl_patch(self):
        source = module("queue_pins", ROOT / "scripts/prepare-syllable-queue.py")
        self.assertEqual(source.REV, "579e480a005321cc320e7e355e8dff398b689be8")
        self.assertEqual(source.FILES["system/sys/appserver/libsyllable/util/messagequeue.cpp"],
                         "c17acce2749301f9821477972a9761f37603e56997a12f076fc75cd11dedd562")
        text = (ROOT / "ports/syllable/patches/messagequeue-rv32.patch").read_text()
        self.assertIn("SPDX-License-Identifier: LGPL-2.0-only", text)
        self.assertNotIn("BSD-2-Clause", text)
        self.assertIn("m_pcLastMessage = pcPrevious", text)

    def test_modified_source_rejected_before_patch(self):
        p = module("queue_modified", ROOT / "scripts/prepare-syllable-queue.py")
        with tempfile.TemporaryDirectory(dir=ROOT/"build", prefix="queue-host-") as directory:
            root = Path(directory)
            file = root/"third_party/syllable/system/sys/appserver/libsyllable/util/messagequeue.cpp"
            file.parent.mkdir(parents=True)
            file.write_text("HOST MODIFIED SOURCE\n")
            with patch.object(p,"ROOT",root), patch.object(p,"OUT",root/"build"), patch.object(p,"urlopen") as network, patch.object(p.subprocess,"run") as apply:
                with self.assertRaisesRegex(RuntimeError,"hash mismatch"): p.main()
                network.assert_not_called(); apply.assert_not_called()

    def test_worker_no_allocator_stdio_decode_or_pthread(self):
        text = (ROOT/"userland/syllable_queue_probe.cpp").read_text().split("int32 Run() override",1)[1].split("static void gate_a()",1)[0]
        for token in ("new ", "malloc(", "free(", "printf(", "puts(", "Unflatten(", "ReadPort(", "pthread_create(", "throw "):
            self.assertNotIn(token, text)
        self.assertIn("get_msg_size(incoming)", text)
        self.assertIn("caribe_tcb_initialized_address", text)

    def test_separate_default_adapter(self):
        text = (ROOT/"Makefile").read_text()
        self.assertIn("-DCARIBE_IPC_RAW_THREAD -msmall-data-limit=0", text)
        self.assertIn("build/initrd-queue.img: build/initrd-threadapi.img", text)
        old = text.split("build/libcaribe-syllable-native.a:",1)[1].split("\n\n",1)[0]
        self.assertNotIn("syllable_raw_msgport", old)

    def test_kernel_native_wait_preserves_main_process(self):
        path = ROOT.parent.parent/"xnu-2050.48.11/osfmk/riscv32/native_ipc.c"
        if not path.exists(): self.skipTest("paired kernel needed")
        text = path.read_text()
        self.assertIn("boolean_t native = riscv32_native_thread_current()", text)
        self.assertIn("if (!native && !riscv32_linux_process_transition", text)
        self.assertEqual(text.count("simple_lock(&ipc_lock)"), 1)
        self.assertEqual(text.count("simple_unlock(&ipc_lock)"), 1)
        lock = text.split("static void ipc_lock_queue(void)",1)[1].split("static volatile",1)[0]
        self.assertIn("disable_preemption();",lock); self.assertIn("enable_preemption();",lock)
        self.assertNotIn("ipc_lock_queue();",lock)

    def test_python_disabled_dependencies_rejected_before_build(self):
        for option in ("--native-threads-disabled","--native-futex-disabled"):
            result = subprocess.run([sys.executable,str(ROOT/"scripts/test-graphics.py"),"--syllable-queue",option],capture_output=True,text=True)
            self.assertEqual(result.returncode,2)
            self.assertIn("MessageQueue gates require enabled",result.stderr)

    def test_public_runner_forwards_and_rejects_non_graphics(self):
        text = (ROOT/"testproject.ps1").read_text()
        self.assertIn("-SyllableQueue:$SyllableQueue -QueueGate $QueueGate",text)
        result = subprocess.run(["powershell","-NoProfile","-File",str(ROOT/"testproject.ps1"),"-Mode","up","-SyllableQueue"],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn("MessageQueue gates are supported",result.stderr)


class QueueEvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.c=module("queue_evidence_guard",ROOT/"tools/collect-syllable-queue-evidence.py")
        self.digest="a"*64
        rows=[{"path":path,"sha256":self.digest} for path in sorted(self.c.REBUILD_PATHS)]
        self.record={"result":"PASS","before":rows,"after":rows,"forcedKernelUnits":["native_ipc","syscall"],
                     "forcedUserUnits":["messagequeue.cpp","syllable_queue_probe.cpp","msgport.c"],
                     "priorThreadArtifactsUnchangedExceptKernel":True}

    def validate(self):
        with patch.object(self.c.base,"sha",return_value=self.digest):
            self.c.validate_rebuild(self.record,{"xnu":self.digest})

    def test_consistent_host_rebuild_fixture(self): self.validate()
    def test_missing_kernel_unit(self):
        self.record["forcedKernelUnits"]=["native_ipc"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_missing_default_adapter(self):
        self.record["after"]=[r for r in self.record["after"] if r["path"]!="build/syllable_msgport.o"]
        self.record["before"]=self.record["after"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_missing_previous_preservation(self):
        self.record["priorThreadArtifactsUnchangedExceptKernel"]=False
        with self.assertRaises(RuntimeError): self.validate()
    def test_duplicate_artifact(self):
        self.record["after"]=self.record["after"][:-1]+[self.record["after"][0]]
        self.record["before"]=self.record["after"]
        with self.assertRaises(RuntimeError): self.validate()
    def test_current_kernel_hash_required(self):
        with patch.object(self.c.base,"sha",return_value=self.digest):
            with self.assertRaises(RuntimeError): self.c.validate_rebuild(self.record,{"xnu":"b"*64})
    def test_short_distinct_evidence_paths(self):
        self.assertEqual(len(self.c.CASE_SLUGS),11)
        self.assertEqual(len(set(self.c.CASE_SLUGS.values())),11)
        for slug in self.c.CASE_SLUGS.values():
            self.assertLess(len(slug),24); self.assertNotIn("/",slug); self.assertNotIn("..",slug)
    def test_no_promotion_before_fresh_processes(self):
        text=(ROOT/"tools/collect-syllable-queue-evidence.py").read_text()
        self.assertLess(text.index("checked = check_up_progressive(current)"),text.index("# Promotion is separate"))
        self.assertLess(text.index("parent.validate_process_regression(current)"),text.index("# Promotion is separate"))


if __name__ == "__main__":
    unittest.main()
