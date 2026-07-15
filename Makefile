SBI ?= 1
PYTHON ?= python
XNU_FULL_STAGE0 ?= ../../xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf
KERNEL_ELF ?= $(XNU_FULL_STAGE0)
INIT_ELF ?= build/init_stage1.elf
CARIBED_ELF ?= build/caribed.elf
CARIBECTL_ELF ?= build/caribectl.elf
MUSL_PROBE_ELF ?= build/musl_probe.elf
INTERACTIVE_INIT_ELF ?= build/interactive_init.elf
PIPELINE_PRODUCER_ELF ?= build/pipeline_producer.elf
PIPELINE_CONSUMER_ELF ?= build/pipeline_consumer.elf
PIPELINE_SIGPIPE_ELF ?= build/pipeline_sigpipe.elf
JOBCTL_WAIT_ELF ?= build/jobctl_wait.elf
CPU1_PROBE_ELF ?= build/cpu1_probe.elf
GATE14_STRESS_ELF ?= build/gate14_stress.elf
GATE14_WORKER_ELF ?= build/gate14_worker.elf
GATE15_PROCESS_STRESS_ELF ?= build/gate15_process_stress.elf
GATE15_WORKER_ELF ?= build/gate15_worker.elf
GATE15_PIPE_STRESS_ELF ?= build/gate15_pipe_stress.elf
GATE15_SIGNAL_STRESS_ELF ?= build/gate15_signal_stress.elf
GATE15_PIPELINE_STRESS_ELF ?= build/gate15_pipeline_stress.elf
GATE15_BATCH_STRESS_ELF ?= build/gate15_batch_stress.elf
GATE15_TTY_STRESS_ELF ?= build/gate15_tty_stress.elf
PROCESS_EXIT7_ELF ?= build/process_exit7.elf
PROCESS_TWO_TASK_ELF ?= build/process_two_task.elf
PROCESS_FORK_VM_ELF ?= build/process_fork_vm.elf
PROCESS_FD_PARENT_ELF ?= build/process_fd_parent.elf
PROCESS_FD_EXEC_ELF ?= build/process_fd_exec.elf
PROCESS_EXEC_PARENT_ELF ?= build/process_exec_parent.elf
PROCESS_EXEC_CHILD_ELF ?= build/process_exec_child.elf
PROCESS_EXEC_BADINTERP_ELF ?= build/process_exec_badinterp.elf
PROCESS_WAIT_PARENT_ELF ?= build/process_wait_parent.elf
PROCESS_SIGNAL_PARENT_ELF ?= build/process_signal_parent.elf
PROCESS_SIGNAL_SELF_ELF ?= build/process_signal_self.elf
PROCESS_TTY_INPUT_ELF ?= build/process_tty_input.elf
MUSL_SYSROOT ?= build/musl-rv32-sysroot
BASH_ELF ?= build/bash-rv32/bash
INTERP_PROBE_ELF ?= build/interp_probe.elf
DYNAMIC_PROBE_ELF ?= build/dynamic_probe.elf
DYNAMIC_BIAS_PROBE_ELF ?= build/dynamic_bias_probe.elf
DYNAMIC_BADVER_PROBE_ELF ?= build/dynamic_badver_probe.elf
DYNAMIC_BADVER_BIAS_PROBE_ELF ?= build/dynamic_badver_bias_probe.elf
DYNAMIC_BADMAINVERSYM_PROBE_ELF ?= build/dynamic_badmainversym_probe.elf
DYNAMIC_BADMAINVERSYM_BIAS_PROBE_ELF ?= build/dynamic_badmainversym_bias_probe.elf
LD_CARIBE_ELF ?= build/ld-caribe-rv32.so.1
LIBCARIBE_PROBE_BASE_ELF ?= build/libcaribe_probe.elf
LIBCARIBE_PROBE_ELF ?= build/libcaribe-probe.so.1
LIBCARIBE_EXTRA_BASE_ELF ?= build/libcaribe_extra.elf
LIBCARIBE_EXTRA_ELF ?= build/libcaribe-extra.so.1
LIBCARIBE_CHAIN_BASE_ELF ?= build/libcaribe_chain.elf
LIBCARIBE_CHAIN_ELF ?= build/libcaribe-chain.so.1
LIBCARIBE_BUCKETS_BASE_ELF ?= build/libcaribe_buckets.elf
LIBCARIBE_BUCKETS_ELF ?= build/libcaribe-buckets.so.1
LIBCARIBE_BUCKETS_BADVERSYM_BASE_ELF ?= build/libcaribe_buckets_badversym.elf
LIBCARIBE_BUCKETS_BADVERSYM_ELF ?= build/libcaribe-buckets-badversym.so.1
LIBCARIBE_BUCKETS_NOVERSYM_BASE_ELF ?= build/libcaribe_buckets_noversym.elf
LIBCARIBE_BUCKETS_NOVERSYM_ELF ?= build/libcaribe-buckets-noversym.so.1
LIBCARIBE_BUCKETS_SYSV_BADVERSYM_BASE_ELF ?= build/libcaribe_buckets_sysv_badversym.elf
LIBCARIBE_BUCKETS_SYSV_BADVERSYM_ELF ?= build/libcaribe-buckets-sysv-badversym.so.1
LIBCARIBE_BUCKETS_BADVERNAME_BASE_ELF ?= build/libcaribe_buckets_badvername.elf
LIBCARIBE_BUCKETS_BADVERNAME_ELF ?= build/libcaribe-buckets-badvername.so.1
INITRD_IMG ?= build/initrd.img
INITRD_BADVER_IMG ?= build/initrd_badver.img
INITRD_BADMAINVERSYM_IMG ?= build/initrd_badmainversym.img
INITRD_BADVERSYM_IMG ?= build/initrd_badversym.img
INITRD_NOVERSYM_IMG ?= build/initrd_noversym.img
INITRD_SYSV_BADVERSYM_IMG ?= build/initrd_sysv_badversym.img
INITRD_BADVERNAME_IMG ?= build/initrd_badvername.img
QEMU_SMOKE_SECONDS ?= 30
GATE15_SECONDS ?= 180
STAGE1_FILES := \
	userland/stage1/etc/os-release \
	userland/stage1/etc/caribe-release \
	userland/stage1/etc/passwd \
	userland/stage1/etc/group \
	userland/stage1/caribe/stage1.manifest \
	userland/stage1/usr/lib/caribe.note \
	userland/stage1/usr/lib/process-fd-fixture \
	userland/stage1/usr/lib/bash-smoke.sh \
	userland/stage1/usr/bin/dynamic-script

CC32 := $(shell \
  command -v riscv32-unknown-elf-gcc 2>/dev/null || \
  command -v riscv64-unknown-elf-gcc 2>/dev/null || echo clang)
OBJCOPY32 := $(shell \
  command -v riscv32-unknown-elf-objcopy 2>/dev/null || \
  command -v riscv64-unknown-elf-objcopy 2>/dev/null || \
  command -v llvm-objcopy 2>/dev/null || \
  command -v llvm-objcopy-19 2>/dev/null || \
  command -v objcopy 2>/dev/null || echo objcopy)

ifeq ($(notdir $(CC32)),clang)
  TGT32 := --target=riscv32-unknown-elf
  LD32 := -fuse-ld=lld
else
  TGT32 :=
  LD32 :=
endif

ARCH32 ?= rv32imac_zicsr_zifencei
CFLAGS32  := $(TGT32) -I. -march=$(ARCH32) -mabi=ilp32 -ffreestanding -nostdlib -O2 -Wall -Wextra

ifeq ($(SBI),1)
  LINK_LD := mfw/link_sbi.ld
else
  LINK_LD := mfw/link.ld
endif
LDFLAGS32 := $(TGT32) $(LD32) -Wl,-T $(LINK_LD) -Wl,--no-relax

CSRCS := mfw/mfw.c mfw/virt_dtb.c \
         booter/fdt_min.c \
         booter/uart.c booter/print.c booter/bootargs_pack.c \
         booter/mmu_sv32.c booter/plic_min.c booter/console.c booter/trap.c \
         booter/hfsplus_boot.c booter/booter.c \
         virtio_blk_legacy.c

ifeq ($(SBI),1)
  SSRCS := mfw/scrt0.S booter/trap_entry.S
else
  SSRCS := mfw/start.S booter/trap_entry.S
endif

COBJS := $(patsubst %.c,build/%.c.o,$(CSRCS))
SOBJS := $(patsubst %.S,build/%.S.o,$(SSRCS))
OBJS  := $(COBJS) $(SOBJS)

all: mfw/virt_dtb.c build/caribe_rv32.elf build/caribe_rv32.bin

kernel_entry: build/kernel_xnu_entry.elf

hfs_kernel: $(KERNEL_ELF)
	$(PYTHON) scripts/update-hfs-kernel.py hfsplus.img $(KERNEL_ELF) --allow-grow

hfs_initrd: $(INITRD_IMG)
	$(PYTHON) scripts/update-hfs-kernel.py hfsplus.img $(INITRD_IMG) --path //initrd.img --allow-grow || \
	$(PYTHON) scripts/hfs-create-root-file.py hfsplus.img //initrd.img $(INITRD_IMG)

smoke_sbi: all hfs_kernel
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -Seconds $(QEMU_SMOKE_SECONDS)

smoke_sbi_with_initrd: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS)

boot_stage1: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS)

boot_stage1_process_gate_2: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2"

boot_stage1_process_gate_2_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2"

boot_stage1_process_gate_3: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3"

boot_stage1_process_gate_3_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3"

boot_stage1_process_gate_4: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4"

boot_stage1_process_gate_4_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4"

boot_stage1_process_gate_5: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4 process-gate-5"

boot_stage1_process_gate_5_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4 process-gate-5"

boot_stage1_process_gate_6: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6"

boot_stage1_process_gate_6_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6"

boot_stage1_process_gate_7: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7"

boot_stage1_process_gate_7_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7"

boot_stage1_process_gate_7_only: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-7"

boot_stage1_process_gate_7_only_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-7"

boot_stage1_process_gate_8: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7 process-gate-8"

boot_stage1_process_gate_8_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7 process-gate-8"

boot_stage1_process_gate_8_only: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-8"

boot_stage1_process_gate_8_only_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-8"

boot_stage1_process_gate_9: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7 process-gate-8 process-gate-9"

boot_stage1_process_gate_9_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-2 process-gate-3 process-gate-4 process-gate-5 process-gate-6 process-gate-7 process-gate-8 process-gate-9"

boot_stage1_process_gate_9_only: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-9"

boot_stage1_process_gate_9_only_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f process-gate-9"

boot_stage1_process_gate_10_only: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-tty-test.ps1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-10"

boot_stage1_process_gate_10_only_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-tty-test.ps1 -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-10"

boot_stage1_process_gate_11: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Seconds $(QEMU_SMOKE_SECONDS) -Append "process-gate-11"

boot_stage1_process_gate_11_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-11"

boot_stage1_process_gate_12: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 12 -Seconds $(QEMU_SMOKE_SECONDS)

boot_stage1_process_gate_12_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 12 -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-11 process-gate-12"

boot_stage1_process_gate_13: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 13 -Seconds $(QEMU_SMOKE_SECONDS)

boot_stage1_process_gate_13_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 13 -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-11 process-gate-13"

boot_stage1_process_gate_14: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 14 -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-11 process-gate-14"

GATE14_STRESS_ROUNDS ?= 10000

boot_stage1_process_gate_14_stress: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 14 -StressRounds $(GATE14_STRESS_ROUNDS) -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -RequireSmpGateF

boot_stage1_process_gate_15: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 15 -Seconds $(GATE15_SECONDS)

boot_stage1_process_gate_15_smp: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-bash-interactive.ps1 -Gate 15 -Seconds $(GATE15_SECONDS) -Smp 2 -RequireSmpGateF -Append "smp-start smp-gate-f process-gate-11 process-gate-15"

boot_stage1_smp: boot_stage1_smp_gate_a

boot_stage1_smp_gate_a: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate A -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-smoke"

boot_stage1_smp_gate_b: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate B -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-smoke smp-gate-b"

boot_stage1_smp_gate_c: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate C -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-c"

boot_stage1_smp_gate_d: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate D -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-d"

boot_stage1_smp_gate_e: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate E -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-e"

boot_stage1_smp_gate_f: all hfs_kernel hfs_initrd
	powershell -ExecutionPolicy Bypass -File scripts/qemu-rv32-sbi.ps1 -SmokeTest -RequireStage1 -RequireSmpGate F -Seconds $(QEMU_SMOKE_SECONDS) -Smp 2 -Append "smp-start smp-gate-f"

boot_stage1_badver_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_BADVER_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_BADVER_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "VERNEED provider match=0x00000000" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-badver.txt -RunLog build/qemu-negative-badver-run.txt

boot_stage1_badmainversym_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_BADMAINVERSYM_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_BADMAINVERSYM_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "MAIN sym versym=0x00000003" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-badmainversym.txt -RunLog build/qemu-negative-badmainversym-run.txt

boot_stage1_badversym_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_BADVERSYM_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_BADVERSYM_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "GNU_HASH versym check=0x00000000" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-badversym.txt -RunLog build/qemu-negative-badversym-run.txt

boot_stage1_noversym_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_NOVERSYM_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_NOVERSYM_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "GNU_HASH missing VERSYM check=0x00000000" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-noversym.txt -RunLog build/qemu-negative-noversym-run.txt

boot_stage1_sysv_badversym_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_SYSV_BADVERSYM_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_SYSV_BADVERSYM_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "SYMTAB versym check=0x00000000" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-sysv-badversym.txt -RunLog build/qemu-negative-sysv-badversym-run.txt

boot_stage1_badvername_expected_fail: all hfs_kernel $(INITRD_IMG) $(INITRD_BADVERNAME_IMG)
	powershell -ExecutionPolicy Bypass -File scripts/qemu-stage1-negative-initrd.ps1 -BadInitrd $(INITRD_BADVERNAME_IMG) -GoodInitrd $(INITRD_IMG) -ExpectedPattern "VERNEED name match=0x00000000" -Seconds $(QEMU_SMOKE_SECONDS) -EvidenceLog build/qemu-negative-badvername.txt -RunLog build/qemu-negative-badvername-run.txt

mfw/virt_dtb.c: scripts/dump-dtb.sh
	@bash scripts/dump-dtb.sh

build/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -c $< -o $@

build/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -c $< -o $@

build/caribe_rv32.elf: $(OBJS)
	$(CC32) $(CFLAGS32) $(OBJS) $(LDFLAGS32) -o $@

build/caribe_rv32.bin: build/caribe_rv32.elf
	$(OBJCOPY32) -O binary $< $@

build/kernel_xnu_stage0_trap.S.o: kernel_xnu_stage0_trap.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -c $< -o $@

build/kernel_xnu_entry.elf: kernel_xnu_entry.c kernel_xnu_stage0_trap.S rv32_payload.ld build/kernel_xnu_stage0_trap.S.o
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) $(TGT32) $(LD32) -static -Wl,--gc-sections -Wl,-T rv32_payload.ld -Wl,--no-relax kernel_xnu_entry.c build/kernel_xnu_stage0_trap.S.o -o $@

build/init_smoke.elf: userland/init_smoke.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x10000 -Wl,--no-relax $< -o $@

build/init_stage1.elf: userland/init_stage1.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x10000 -Wl,--no-relax $< -o $@

build/process_exit7.elf: userland/process_exit7.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x18000 -Wl,--no-relax $< -o $@

build/process_two_task.elf: userland/process_two_task.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x1a000 -Wl,--no-relax $< -o $@

build/process_fork_vm.elf: userland/process_fork_vm.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x1c000 -Wl,--no-relax $< -o $@

build/process_fd_parent.elf: userland/process_fd_parent.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x1e000 -Wl,--no-relax $< -o $@

build/process_fd_exec.elf: userland/process_fd_exec.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x20000 -Wl,--no-relax $< -o $@

build/process_exec_parent.elf: userland/process_exec_parent.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x22000 -Wl,--no-relax $< -o $@

build/process_exec_child.elf: userland/process_exec_child.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x26000 -Wl,--no-relax $< -o $@

build/process_exec_badinterp.elf: userland/process_exec_badinterp.S userland/process_exec_badinterp.ld
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-T,userland/process_exec_badinterp.ld -Wl,--no-relax $< -o $@

build/process_wait_parent.elf: userland/process_wait_parent.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x2e000 -Wl,--no-relax $< -o $@

build/process_signal_parent.elf: userland/process_signal_parent.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x32000 -Wl,--no-relax $< -o $@

build/process_signal_self.elf: userland/process_signal_self.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x36000 -Wl,--no-relax $< -o $@

build/process_tty_input.elf: userland/process_tty_input.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x3a000 -Wl,--no-relax $< -o $@

build/caribed.elf: userland/caribed.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x20000 -Wl,--no-relax $< -o $@

build/caribectl.elf: userland/caribectl.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x30000 -Wl,--no-relax $< -o $@

build/interp_probe.elf: userland/interp_probe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x22000 -Wl,--no-relax $< -o $@

build/dynamic_probe.elf: userland/dynamic_probe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x24000 -Wl,--no-relax $< -o $@

build/dynamic_bias_probe.elf: $(DYNAMIC_PROBE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(DYNAMIC_PROBE_ELF) $@ ET_DYN

build/dynamic_badver_probe.elf: userland/dynamic_probe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_BUCKETS_VERNEED_OTHER=3 -nostdlib -static -Wl,-Ttext=0x24000 -Wl,--no-relax $< -o $@

build/dynamic_badver_bias_probe.elf: $(DYNAMIC_BADVER_PROBE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(DYNAMIC_BADVER_PROBE_ELF) $@ ET_DYN

build/dynamic_badmainversym_probe.elf: userland/dynamic_probe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_MAIN_BUCKETS_VERSYM_INDEX=3 -nostdlib -static -Wl,-Ttext=0x24000 -Wl,--no-relax $< -o $@

build/dynamic_badmainversym_bias_probe.elf: $(DYNAMIC_BADMAINVERSYM_PROBE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(DYNAMIC_BADMAINVERSYM_PROBE_ELF) $@ ET_DYN

build/ld-caribe-rv32.so.1: userland/ld_caribe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x40000 -Wl,--no-relax $< -o $@

build/libcaribe_probe.elf: userland/libcaribe_probe.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x26000 -Wl,--no-relax $< -o $@

build/libcaribe-probe.so.1: $(LIBCARIBE_PROBE_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_PROBE_BASE_ELF) $@ ET_DYN

build/libcaribe_extra.elf: userland/libcaribe_extra.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x28000 -Wl,--no-relax $< -o $@

build/libcaribe-extra.so.1: $(LIBCARIBE_EXTRA_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_EXTRA_BASE_ELF) $@ ET_DYN

build/libcaribe_chain.elf: userland/libcaribe_chain.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x2a000 -Wl,--no-relax $< -o $@

build/libcaribe-chain.so.1: $(LIBCARIBE_CHAIN_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_CHAIN_BASE_ELF) $@ ET_DYN

build/libcaribe_buckets.elf: userland/libcaribe_buckets.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x2c000 -Wl,--no-relax $< -o $@

build/libcaribe-buckets.so.1: $(LIBCARIBE_BUCKETS_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_BUCKETS_BASE_ELF) $@ ET_DYN

build/libcaribe_buckets_badversym.elf: userland/libcaribe_buckets.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_BUCKETS_VERSYM_INDEX=3 -nostdlib -static -Wl,-Ttext=0x2c000 -Wl,--no-relax $< -o $@

build/libcaribe-buckets-badversym.so.1: $(LIBCARIBE_BUCKETS_BADVERSYM_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_BUCKETS_BADVERSYM_BASE_ELF) $@ ET_DYN

build/libcaribe_buckets_noversym.elf: userland/libcaribe_buckets.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_BUCKETS_NO_VERSYM=1 -nostdlib -static -Wl,-Ttext=0x2c000 -Wl,--no-relax $< -o $@

build/libcaribe-buckets-noversym.so.1: $(LIBCARIBE_BUCKETS_NOVERSYM_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_BUCKETS_NOVERSYM_BASE_ELF) $@ ET_DYN

build/libcaribe_buckets_sysv_badversym.elf: userland/libcaribe_buckets.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_BUCKETS_NO_GNU_HASH=1 -DCARIBE_BUCKETS_VERSYM_INDEX=3 -nostdlib -static -Wl,-Ttext=0x2c000 -Wl,--no-relax $< -o $@

build/libcaribe-buckets-sysv-badversym.so.1: $(LIBCARIBE_BUCKETS_SYSV_BADVERSYM_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_BUCKETS_SYSV_BADVERSYM_BASE_ELF) $@ ET_DYN

build/libcaribe_buckets_badvername.elf: userland/libcaribe_buckets.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -DCARIBE_BUCKETS_BAD_VERDEF_NAME=1 -nostdlib -static -Wl,-Ttext=0x2c000 -Wl,--no-relax $< -o $@

build/libcaribe-buckets-badvername.so.1: $(LIBCARIBE_BUCKETS_BADVERNAME_BASE_ELF) scripts/elf32-set-type.py
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/elf32-set-type.py $(LIBCARIBE_BUCKETS_BADVERNAME_BASE_ELF) $@ ET_DYN

musl_rv32:
	powershell -ExecutionPolicy Bypass -File scripts/build-musl-rv32.ps1

bash_rv32: $(BASH_ELF)

$(BASH_ELF): scripts/build-bash-rv32.ps1 scripts/riscv32-musl-gcc.sh scripts/bash-host-gcc.sh scripts/bash-host-build-compat.h scripts/bash-rv32-pipesize.h $(MUSL_SYSROOT)/usr/lib/libc.a
	powershell -ExecutionPolicy Bypass -File scripts/build-bash-rv32.ps1

build/musl_probe.o: userland/musl_probe.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/musl_probe.elf: build/musl_probe.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/interactive_init.o: userland/interactive_init.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/interactive_init.elf: build/interactive_init.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/pipeline_producer.o: userland/pipeline_producer.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/pipeline_producer.elf: build/pipeline_producer.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/pipeline_consumer.o: userland/pipeline_consumer.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/pipeline_consumer.elf: build/pipeline_consumer.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/pipeline_sigpipe.o: userland/pipeline_sigpipe.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/pipeline_sigpipe.elf: build/pipeline_sigpipe.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/jobctl_wait.o: userland/jobctl_wait.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/jobctl_wait.elf: build/jobctl_wait.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/cpu1_probe.o: userland/cpu1_probe.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/cpu1_probe.elf: build/cpu1_probe.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate14_stress.elf: userland/gate14_stress.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x3c000 -Wl,--no-relax $< -o $@

build/gate14_worker.elf: userland/gate14_worker.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x3e000 -Wl,--no-relax $< -o $@

build/gate15_process_stress.o: userland/gate15_process_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_process_stress.elf: build/gate15_process_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate15_worker.elf: userland/gate15_worker.S
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdlib -static -Wl,-Ttext=0x40000 -Wl,--no-relax $< -o $@

build/gate15_pipe_stress.o: userland/gate15_pipe_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_pipe_stress.elf: build/gate15_pipe_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate15_signal_stress.o: userland/gate15_signal_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_signal_stress.elf: build/gate15_signal_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate15_pipeline_stress.o: userland/gate15_pipeline_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_pipeline_stress.elf: build/gate15_pipeline_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate15_batch_stress.o: userland/gate15_batch_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_batch_stress.elf: build/gate15_batch_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/gate15_tty_stress.o: userland/gate15_tty_stress.c $(MUSL_SYSROOT)/usr/lib/libc.a
	@mkdir -p $(dir $@)
	$(CC32) $(CFLAGS32) -nostdinc -I$(MUSL_SYSROOT)/usr/include \
	  -ffunction-sections -fdata-sections -c $< -o $@

build/gate15_tty_stress.elf: build/gate15_tty_stress.o $(MUSL_SYSROOT)/usr/lib/libc.a
	$(CC32) -march=$(ARCH32) -mabi=ilp32 -nostdlib -static \
	  -Wl,--gc-sections -Wl,--no-relax -Wl,-e,_start \
	  $(MUSL_SYSROOT)/usr/lib/crt1.o $(MUSL_SYSROOT)/usr/lib/crti.o \
	  $< -L$(MUSL_SYSROOT)/usr/lib -lc -lgcc \
	  $(MUSL_SYSROOT)/usr/lib/crtn.o -o $@

build/initrd.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(MUSL_PROBE_ELF) $(INTERACTIVE_INIT_ELF) $(PIPELINE_PRODUCER_ELF) $(PIPELINE_CONSUMER_ELF) $(PIPELINE_SIGPIPE_ELF) $(JOBCTL_WAIT_ELF) $(CPU1_PROBE_ELF) $(GATE14_STRESS_ELF) $(GATE14_WORKER_ELF) $(GATE15_PROCESS_STRESS_ELF) $(GATE15_WORKER_ELF) $(GATE15_PIPE_STRESS_ELF) $(GATE15_SIGNAL_STRESS_ELF) $(GATE15_PIPELINE_STRESS_ELF) $(GATE15_BATCH_STRESS_ELF) $(GATE15_TTY_STRESS_ELF) $(PROCESS_EXIT7_ELF) $(PROCESS_TWO_TASK_ELF) $(PROCESS_FORK_VM_ELF) $(PROCESS_FD_PARENT_ELF) $(PROCESS_FD_EXEC_ELF) $(PROCESS_EXEC_PARENT_ELF) $(PROCESS_EXEC_CHILD_ELF) $(PROCESS_EXEC_BADINTERP_ELF) $(PROCESS_WAIT_PARENT_ELF) $(PROCESS_SIGNAL_PARENT_ELF) $(PROCESS_SIGNAL_SELF_ELF) $(PROCESS_TTY_INPUT_ELF) $(BASH_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  sbin/interactive-init=$(INTERACTIVE_INIT_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/musl-probe=$(MUSL_PROBE_ELF) \
	  bin/pipeline-producer=$(PIPELINE_PRODUCER_ELF) \
	  bin/pipeline-consumer=$(PIPELINE_CONSUMER_ELF) \
	  bin/pipeline-sigpipe=$(PIPELINE_SIGPIPE_ELF) \
	  bin/jobctl-wait=$(JOBCTL_WAIT_ELF) \
	  bin/cpu1-probe=$(CPU1_PROBE_ELF) \
	  bin/gate14-stress=$(GATE14_STRESS_ELF) \
	  bin/gate14-worker=$(GATE14_WORKER_ELF) \
	  bin/gate15-process=$(GATE15_PROCESS_STRESS_ELF) \
	  bin/gate15-worker=$(GATE15_WORKER_ELF) \
	  bin/gate15-pipes=$(GATE15_PIPE_STRESS_ELF) \
	  bin/gate15-signals=$(GATE15_SIGNAL_STRESS_ELF) \
	  bin/gate15-pipelines=$(GATE15_PIPELINE_STRESS_ELF) \
	  bin/gate15-batches=$(GATE15_BATCH_STRESS_ELF) \
	  bin/gate15-tty=$(GATE15_TTY_STRESS_ELF) \
	  bin/process-exit7=$(PROCESS_EXIT7_ELF) \
	  bin/process-two-task=$(PROCESS_TWO_TASK_ELF) \
	  bin/process-fork-vm=$(PROCESS_FORK_VM_ELF) \
	  bin/process-fd-parent=$(PROCESS_FD_PARENT_ELF) \
	  bin/process-fd-exec=$(PROCESS_FD_EXEC_ELF) \
	  bin/process-exec-parent=$(PROCESS_EXEC_PARENT_ELF) \
	  bin/process-exec-child=$(PROCESS_EXEC_CHILD_ELF) \
	  bin/process-exec-badinterp=$(PROCESS_EXEC_BADINTERP_ELF) \
	  bin/process-wait-parent=$(PROCESS_WAIT_PARENT_ELF) \
	  bin/process-signal-parent=$(PROCESS_SIGNAL_PARENT_ELF) \
	  bin/process-signal-self=$(PROCESS_SIGNAL_SELF_ELF) \
	  bin/process-tty-input=$(PROCESS_TTY_INPUT_ELF) \
	  bin/bash=$(BASH_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  etc/passwd=userland/stage1/etc/passwd \
	  etc/group=userland/stage1/etc/group \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/lib/process-fd-fixture=userland/stage1/usr/lib/process-fd-fixture \
	  usr/lib/bash-smoke.sh=userland/stage1/usr/lib/bash-smoke.sh \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_badver.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BADVER_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BADVER_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_badmainversym.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BADMAINVERSYM_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BADMAINVERSYM_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_badversym.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_BADVERSYM_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_BADVERSYM_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_noversym.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_NOVERSYM_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_NOVERSYM_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_sysv_badversym.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_SYSV_BADVERSYM_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_SYSV_BADVERSYM_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

build/initrd_badvername.img: $(INIT_ELF) $(CARIBED_ELF) $(CARIBECTL_ELF) $(INTERP_PROBE_ELF) $(DYNAMIC_PROBE_ELF) $(DYNAMIC_BIAS_PROBE_ELF) $(LD_CARIBE_ELF) $(LIBCARIBE_PROBE_ELF) $(LIBCARIBE_EXTRA_ELF) $(LIBCARIBE_CHAIN_ELF) $(LIBCARIBE_BUCKETS_BADVERNAME_ELF) scripts/make-newc-initrd.py $(STAGE1_FILES)
	@mkdir -p $(dir $@)
	$(PYTHON) scripts/make-newc-initrd.py $@ \
	  init=$(INIT_ELF) \
	  sbin/init=$(CARIBED_ELF) \
	  sbin/caribed=$(CARIBED_ELF) \
	  bin/caribectl=$(CARIBECTL_ELF) \
	  bin/interp-probe=$(INTERP_PROBE_ELF) \
	  bin/dynamic-probe=$(DYNAMIC_PROBE_ELF) \
	  bin/dynamic-bias-probe=$(DYNAMIC_BIAS_PROBE_ELF) \
	  lib/ld-caribe-rv32.so.1=$(LD_CARIBE_ELF) \
	  lib/libcaribe-probe.so.1=$(LIBCARIBE_PROBE_ELF) \
	  lib/libcaribe-extra.so.1=$(LIBCARIBE_EXTRA_ELF) \
	  lib/libcaribe-chain.so.1=$(LIBCARIBE_CHAIN_ELF) \
	  lib/libcaribe-buckets.so.1=$(LIBCARIBE_BUCKETS_BADVERNAME_ELF) \
	  etc/os-release=userland/stage1/etc/os-release \
	  etc/caribe-release=userland/stage1/etc/caribe-release \
	  caribe/stage1.manifest=userland/stage1/caribe/stage1.manifest \
	  usr/lib/caribe.note=userland/stage1/usr/lib/caribe.note \
	  usr/bin/dynamic-script=userland/stage1/usr/bin/dynamic-script

run: all
	bash scripts/qemu-rv32.sh

run_sbi: all
	bash scripts/qemu-rv32-sbi.sh

dtb:
	bash scripts/dump-dtb.sh

clean:
	rm -rf build
	rm -f mfw/virt_dtb.c

.PHONY: all kernel_entry musl_rv32 bash_rv32 hfs_kernel hfs_initrd smoke_sbi smoke_sbi_with_initrd boot_stage1 boot_stage1_process_gate_2 boot_stage1_process_gate_2_smp boot_stage1_process_gate_3 boot_stage1_process_gate_3_smp boot_stage1_process_gate_4 boot_stage1_process_gate_4_smp boot_stage1_process_gate_5 boot_stage1_process_gate_5_smp boot_stage1_process_gate_6 boot_stage1_process_gate_6_smp boot_stage1_process_gate_7 boot_stage1_process_gate_7_smp boot_stage1_process_gate_7_only boot_stage1_process_gate_7_only_smp boot_stage1_process_gate_8 boot_stage1_process_gate_8_smp boot_stage1_process_gate_8_only boot_stage1_process_gate_8_only_smp boot_stage1_process_gate_9 boot_stage1_process_gate_9_smp boot_stage1_process_gate_9_only boot_stage1_process_gate_9_only_smp boot_stage1_process_gate_10_only boot_stage1_process_gate_10_only_smp boot_stage1_process_gate_11 boot_stage1_process_gate_11_smp boot_stage1_process_gate_12 boot_stage1_process_gate_12_smp boot_stage1_process_gate_13 boot_stage1_process_gate_13_smp boot_stage1_process_gate_14 boot_stage1_process_gate_14_stress boot_stage1_process_gate_15 boot_stage1_process_gate_15_smp boot_stage1_smp boot_stage1_smp_gate_a boot_stage1_smp_gate_b boot_stage1_smp_gate_c boot_stage1_smp_gate_d boot_stage1_smp_gate_e boot_stage1_smp_gate_f boot_stage1_badver_expected_fail boot_stage1_badmainversym_expected_fail boot_stage1_badversym_expected_fail boot_stage1_noversym_expected_fail boot_stage1_sysv_badversym_expected_fail boot_stage1_badvername_expected_fail dtb run run_sbi clean
