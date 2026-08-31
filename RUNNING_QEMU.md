# Running QEMU

## Supported Invocation

The runner and Makefile own the complete device command line. The essential
contract is:

```text
qemu-system-riscv32 -M virt -m 256 -bios default \
  -kernel build/caribe_rv32.elf ...
```

`-bios default` supplies OpenSBI. CaribeBootX is the QEMU kernel payload and
XNU-CaribeOS is loaded by CaribeBootX from HFS+ over virtio-blk.

Do not use the obsolete form:

```text
-bios build/caribe_rv32.bin
```

That path bypasses the required privilege handoff and historically executed
incorrect addresses.

## Automated Runs

```powershell
.\testproject.ps1 -Mode up -Seconds 45
.\testproject.ps1 -Mode smp -Seconds 50
.\testproject.ps1 -Mode gates -Seconds 50
.\testproject.ps1 -Mode interactive -Seconds 120
.\testproject.ps1 -Mode console
```

The script records separate run and serial logs under `build/`, enforces a
timeout, terminates its own QEMU process, and validates semantic markers.

## Interactive Shell

`-Mode interactive` boots the Gate 11 image, waits for the UART TTY path, runs
the scripted interactive Bash exchange, verifies blocking wakeups and process
reaping, and requires Bash to exit with status zero.

`-Mode console` rebuilds the current XNU kernel and runtime image, then attaches
QEMU's serial port directly to the current terminal. Wait for `bash-5.3$` and
type commands normally. It defaults to one hart; use `-Smp 2` to bring up both
kernel processors while keeping Bash on CPU 0. To terminate the VM, press
`Ctrl+A`, release the keys, then press `X`. Running `exit` ends Bash and PID 1,
but intentionally does not power off QEMU.

For an already prepared image, the lower-level equivalent is:

```powershell
.\scripts\qemu-rv32-console.ps1
```

## HFS+ Detail

The loader's on-disk `HFSPlusFileRecord` layout includes the BSD `special`
field before `userInfo[4]`. Removing it misaligns `dataFork` and makes
`kernel.elf` appear empty. See [BOOTFLOW_HFSPLUS.md](BOOTFLOW_HFSPLUS.md).
