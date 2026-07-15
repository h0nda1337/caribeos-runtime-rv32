# CaribeBootX HFS+ Native Boot

Estado verificado:

```text
OpenSBI -> CaribeBootX -> virtio-blk -> hfsplus.img -> /kernel.elf
```

Estado siguiente verificado:

```text
OpenSBI -> CaribeBootX -> HFS+ /kernel.elf -> XNU-CaribeOS stage0
```

El arranque compatible con QEMU `virt` RV32 usa OpenSBI como firmware M-mode:

```powershell
make
make hfs_kernel
make smoke_sbi
```

El comando explícito equivalente para correr solo QEMU es:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\qemu-rv32-sbi.ps1 `
  -QemuPath ..\..\qemu-riscv32-install\qemu-system-riscv32.exe `
  -SmokeTest -Seconds 8
```

La ruta vieja `-bios build/caribe_rv32.bin` queda deshabilitada en
`scripts/qemu-rv32-forcebin.sh`. El camino correcto es:

```text
qemu-system-riscv32 -M virt -m 256 -bios default -kernel build/caribe_rv32.elf
```

con `hfsplus.img` conectado como:

```text
-drive if=none,file=hfsplus.img,format=raw,id=vd0
-device virtio-blk-device,drive=vd0
```

El loader HFS+ en `booter/hfsplus_boot.c` conserva el layout real de
`HFSPlusFileRecord`: el campo BSD `special` esta antes de `userInfo[4]`.
Sin ese campo, `dataFork` queda mal alineado y `/kernel.elf` aparece con
tamano cero.

El artefacto `build/kernel_xnu_entry.elf` es el primer entry controlado para
XNU-CaribeOS RV32: valida que CaribeBootX salta con `a0=hartid`, `a1=dtb` y
`a2=CBX1`. El stage0 actual recibe el contrato, imprime el shape de
`riscv32_kernel_entry`, re-probea `virtio-mmio`, reinicializa `virtio-blk`
desde el lado XNU y vuelve a leer la raiz HFS+ para probar `/kernel.elf`.
Tambien instala un `stvec` propio, programa el timer con SBI legacy
`set_timer`, recibe dos interrupciones `S-timer` y deshabilita `STIE` antes de
entrar al siguiente smoke. Despues instala una tabla Sv32 propia con una
ventana U-mode en `0x81000000`, salta a un payload Linux minimo, atrapa
`getpid`, `getppid`, `gettid`, `getuid`, `geteuid`, `getgid`, `getegid`,
`set_tid_address`, `futex`, `rt_sigaction`, `rt_sigprocmask`, `brk`, `mmap`,
`mremap`, `madvise`, `mprotect`, `munmap`, `uname`, `getcwd`, `sysinfo`,
`prlimit64`, `statfs64`, `faccessat`, `readlinkat`, `statx`, `fstatat64`,
`fstat64`, `fstatfs64`, `getdents64`, `sched_getaffinity`,
`sched_setaffinity`, `getcpu`, `clock_getres_time64`, `nanosleep`,
`ppoll_time64`, `getrusage`, `umask`, `clock_gettime64`, `gettimeofday`,
`getrandom`, `openat`, `read`, `close`, `write`, `writev` y `exit_group`
desde XNU-stage0, y finalmente se estaciona.

Contrato actual con XNU-CaribeOS:

```text
a0 = hartid
a1 = DTB fisico entregado por OpenSBI
a2 = riscv32_caribebootx_args_t*
```

CaribeBootX llena el contrato `CBX1` con RAM, DTB, UART, PLIC, ACLINT,
kernel cargado y linea de comandos. XNU ahora escanea ese DTB para obtener
`timebase-frequency`, RAM real y ventanas `virtio,mmio`; despues inicializa un
camino temprano `virtio-blk` propio para que el siguiente salto sea leer el
root HFS+ desde XNU, no desde el loader.

Log esperado del stage0 actual:

```text
[XNU-CaribeOS] riscv32_kernel_entry
[XNU-CaribeOS] CBX memory map
[riscv32] mmap paddr=0x80208480 count=9 desc=40
  [mem 0] type=1(LoaderCode) start=0x0000000080000000 end=0x0000000080200000 pages=512
  [mem 1] type=1(LoaderCode) start=0x0000000080200000 end=0x0000000080216000 pages=22
  [mem 2] type=7(Conventional) start=0x0000000080216000 end=0x0000000080410000 pages=506
  [mem 3] type=1(LoaderCode) start=0x0000000080410000 end=0x0000000080c84000 pages=2164
  [mem 4] type=7(Conventional) start=0x0000000080c84000 end=0x0000000084000000 pages=13180
  [mem 5] type=2(LoaderData) start=0x0000000084000000 end=0x00000000841a0000 pages=416
  [mem 6] type=7(Conventional) start=0x00000000841a0000 end=0x000000008fe00000 pages=48224
  [mem 7] type=2(LoaderData) start=0x000000008fe00000 end=0x000000008fe02000 pages=2
  [mem 8] type=7(Conventional) start=0x000000008fe02000 end=0x0000000090000000 pages=510
[riscv32] mmap summary conventional_pages=62420 reserved_pages=3116 overlaps=0
[riscv32] vm seed first_free=0x80216000 max_end=0x90000000
[XNU-CaribeOS] PE_init_platform early
[XNU-CaribeOS] pmap bootstrap identity window
[XNU-CaribeOS] virtio-mmio scan
[riscv32] virtio-blk sectors=131072 queue=8
[XNU-CaribeOS] HFS+ root probe
[riscv32] HFS+ sig=0x0000482b version=0x00000004 block=4096
[riscv32] /kernel.elf size=793436 ext0=270+198 head=0x7f454c46
[XNU-CaribeOS] SBI/trap/timer smoke
[riscv32] SBI spec=0x03000000 impl=1 impl_version=0x00010007
[riscv32] timer ticks=2 unhandled=0 scause=0x80000005
[XNU-CaribeOS] Linux personality umode smoke
[riscv32] Sv32 remap for umode old_satp=... new_satp=... user=0x81000000+0x00400000
[riscv32] entering U-mode sepc=0x81000000
[riscv32] linux getpid() -> 42
[riscv32] linux getppid() -> 1
[riscv32] linux gettid() -> 42
[riscv32] linux getuid() -> 0
[riscv32] linux geteuid() -> 0
[riscv32] linux getgid() -> 0
[riscv32] linux getegid() -> 0
[riscv32] linux set_tid_address(addr=0x81001f3c) -> 42
[riscv32] linux futex(uaddr=0x81001ed0, op=1, val=1) -> 0
[riscv32] linux rt_sigaction(sig=2, act=0x00000000, oldact=0x81001ed8) -> 0
[riscv32] linux rt_sigprocmask(how=0, set=0x00000000, oldset=0x81001ee8) -> 0
[riscv32] linux sched_getaffinity(pid=0, len=4) -> 4
[riscv32] linux sched_setaffinity(pid=0, len=4) -> 0
[riscv32] linux getcpu(cpu=0x81001ec8, node=0x81001ec4) -> 0
[riscv32] linux clock_getres_time64(clock=1, tp=0x81001eb8) -> 0
[riscv32] linux nanosleep(req=0x81001eb0, rem=0x00000000) -> 0
[riscv32] linux ppoll_time64(fds=0x00000000, nfds=0) -> 0
[riscv32] linux getrusage(who=0, usage=0x81001e68) -> 0
[riscv32] linux umask(mask=18) -> 18
[riscv32] linux brk(0x00000000) -> 0x81003000
[riscv32] linux mmap(addr=0x00000000, len=4096, prot=0x00000003, flags=0x00000022) -> 0x81004000
[riscv32] linux mremap(old=0x81004000, old_size=4096, new_size=4096) -> 0x81004000
[riscv32] linux madvise(addr=0x81004000, len=4096, advice=0) -> 0
[riscv32] linux mprotect(addr=0x81004000, len=4096) -> 0
[riscv32] linux munmap(addr=0x81004000, len=4096) -> 0
[riscv32] linux uname(buf=0x81001e00) -> Linux/caribeos-rv32/riscv32
[riscv32] linux getcwd(buf=0x81001fc0, size=64) -> "/"
[riscv32] linux sysinfo(info=0x81001f00) -> 0
[riscv32] linux prlimit64(pid=0, resource=3, old=0x81001ef0) -> 0
[riscv32] linux statfs64(path="/") -> 0
[riscv32] linux faccessat(dirfd=AT_FDCWD, path="/proc/self/exe") -> 0
[riscv32] linux readlinkat(path="/proc/self/exe", size=64) -> "/kernel.elf"
[riscv32] linux write(fd=1, len=11) -> /kernel.elf
[riscv32] linux statx(dirfd=AT_FDCWD, path="/proc/version", mask=0x000007ff) -> 0
[riscv32] linux fstatat64(dirfd=AT_FDCWD, path="/proc/version") -> 0
[riscv32] linux openat(dirfd=AT_FDCWD, path="/proc") -> 4
[riscv32] linux fstat64(fd=4) -> 0
[riscv32] linux fstatfs64(fd=4) -> 0
[riscv32] linux getdents64(fd=4, count=160)
  [dirent] name=. ino=5 type=4
  [dirent] name=.. ino=2 type=4
  [dirent] name=self ino=6 type=4
  [dirent] name=version ino=8 type=8
[riscv32] linux getdents64 -> 104
[riscv32] linux close(fd=4) -> 0
[riscv32] linux clock_gettime64(clock=1, tp=0x81001f50) -> sec=...
[riscv32] linux gettimeofday(tv=0x81001f48) -> sec=...
[riscv32] linux getrandom(buf=0x81001f40, len=8) -> 8 deterministic bytes
[riscv32] linux openat(dirfd=AT_FDCWD, path="/proc/version") -> 3
[riscv32] linux read(fd=3, count=96) -> 73
[riscv32] linux write(fd=1, len=73) -> Linux version 0.0.1-caribe ...
[riscv32] linux close(fd=3) -> 0
[riscv32] linux write(fd=1, len=49) -> [umode] Linux write syscall reached XNU-CaribeOS
[riscv32] linux writev(fd=1, iovcnt=1)
  [iov] base=... len=43 -> [umode] Linux writev vector reached stage0
[riscv32] linux exit_group(status=0) syscalls=51 writes=5
[XNU-CaribeOS] kernel_bootstrap parked after umode proof
```

Los primeros 512 pages se reservan deliberadamente para el slot completo
`FW_JUMP` de OpenSBI. El segundo rango es CaribeBootX; XNU no reutiliza ninguno
de los dos aunque el tamano interno de OpenSBI cambie al variar el numero de
harts.

El 2026-05-25 el ELF demo de stage0 mide 34196 bytes y `/kernel.elf` estaba en
`ext0=261+9`, asignado a 9 bloques HFS+. El target
`make hfs_kernel` automatiza esa inyeccion y `make smoke_sbi` ejecuta el
smoke completo.

El 2026-05-25 tambien quedo verificado el primer ELF stage0 construido desde
el arbol XNU:

```powershell
$root = $env:CARIBEOS_WORKSPACE
if (-not $root) { throw 'Set CARIBEOS_WORKSPACE to the workspace root.' }
$xnu = Join-Path $root 'xnu-2050.48.11'
$caribe = Join-Path $root 'caribeos-corrected-xnu-rv32imacsu\caribeos'
$kernel = Join-Path $xnu 'BUILD\obj\RELEASE_RISCV32\osfmk\RELEASE\xnu-caribeos-rv32-stage0.elf'
make -C $caribe smoke_sbi PYTHON=python KERNEL_ELF="$kernel"
```

Ese camino inyecta un `/kernel.elf` de 94820 bytes en HFS+ y arranca por:

```text
OpenSBI -> CaribeBootX -> HFS+ /kernel.elf -> XNU-built riscv32_kernel_entry

[ELF] saltando entry=0x80410004 hart=0 dtb=0x8fe00000 args=0x802087e0 mmap=8
[XNU-CaribeOS] riscv32_kernel_entry
[XNU-CaribeOS] PE_init_platform stage0 shim
[XNU-CaribeOS] kernel_early_bootstrap stage0 shim
[XNU-CaribeOS] kernel_bootstrap stage0 shim parked
QEMU smoke test OK.
```

El 2026-05-31 quedo verificado el siguiente hito con el ELF full-stage0 del
arbol XNU, siempre arrancando con OpenSBI:

```text
OpenSBI -> CaribeBootX -> HFS+ /kernel.elf -> XNU-CaribeOS full-stage0
  -> kernel_bootstrap_thread -> bsd_init -> Linux ABI U-mode smoke
```

El kernel inyectado en HFS+ fue
`xnu-caribeos-rv32-full-stage0.elf`, con `/kernel.elf` de 709444 bytes. El
arranque mantiene el camino correcto:

```text
qemu-system-riscv32 -M virt -m 256 -bios default -kernel build/caribe_rv32.elf
```

Lineas clave del log:

```text
[Boot.plist] flags=console=ttyS0 loglevel=7 BOOT=caribe kernel=/kernel.elf
[boot] kernel size=709444
[ELF] saltando entry=0x80476e80 hart=0 dtb=0x8fe00000 args=0x802087e0 mmap=8
[XNU-CaribeOS] kernel_bootstrap_thread
[XNU-CaribeOS] PE_init_iokit stage0 stub
[XNU-CaribeOS] bsd_init stage0: Linux ABI smoke
[umode] entering smoke test
[umode] Linux write syscall reached XNU-CaribeOS
[umode] Linux writev vector reached stage0
[linux] exit status=0
QEMU smoke test OK.
```

Detalle de implementacion asociado: `copyin`/`copyout` en XNU-CaribeOS ya no
leen buffers de usuario como direcciones directas bajo el pmap equivocado.
Ahora conservan el pmap de usuario del smoke, traducen con `pmap_extract()` y
copian por la ventana fisica del kernel. Esto hizo visibles los buffers de
`write` y `writev` desde U-mode.

Tambien el 2026-05-31 quedo verificado el primer `/init` real entregado por
HFS+ como initrd:

```text
OpenSBI -> CaribeBootX -> HFS+ /kernel.elf + /initrd.img
  -> XNU-CaribeOS -> bsd_init -> cpio:/init ELF
```

`/initrd.img` se genera con:

```powershell
make hfs_initrd PYTHON=python
```

El target compila `userland/init_smoke.S`, crea `build/initrd.img` en formato
`newc` y lo actualiza o crea como `/initrd.img` en el HFS+.

Lineas clave del log:

```text
[boot] initrd cargado /initrd.img @0x84000000 size=5312
[linux-initrd] base=0x84000000 size=0x000014c0 magic=0x30373037 kind=cpio
[linux-initrd] cpio entry init size=0x000013d0
[linux-initrd] selected init paddr=0x84000074 size=0x000013d0 mode=0x000081ed
[linux-exec] init ELF32 entry=0x00010000 loads=1 vaddr=0x0000f000-0x00010054
[XNU-CaribeOS] bsd_init stage0: initrd Linux exec
[linux-exec] entering Linux init smoke entry=0x00010000 sp=0x7ffeffa0
[initrd-init] hello from /init under XNU-CaribeOS
[linux] exit status=0
QEMU smoke test OK.
```

El siguiente hito del 2026-05-31 amplio ese `/init` para ejercer el
subsistema Linux temprano desde U-mode:

```text
OpenSBI -> CaribeBootX -> HFS+ /kernel.elf + /initrd.img
  -> XNU-CaribeOS -> bsd_init -> cpio:/init ELF
  -> Linux ABI pseudo-/proc smoke
```

Lineas clave del log:

```text
[boot] initrd cargado /initrd.img @0x84000000 size=7560
[linux-exec] init ELF32 entry=0x00010000 loads=2 vaddr=0x0000f000-0x000117c8
[XNU-CaribeOS] bsd_init stage0: initrd Linux exec
[initrd-init] Linux ABI smoke v2 under XNU-CaribeOS
[initrd-init] /proc/version: Linux version 0.0.1-caribe (XNU-CaribeOS stage0) rv32imac_zicsr_zifencei
[initrd-init] /proc/cpuinfo:
processor	: 0
hart		: 0
isa		: rv32imac_zicsr_zifencei
mmu		: sv32
platform	: qemu-virt
[initrd-init] /proc/meminfo:
MemTotal:        262144 kB
MemFree:         131072 kB
MemAvailable:    131072 kB
[initrd-init] getdents64(/proc) ok
[initrd-init] readlink(/proc/self/exe): /kernel.elf
[initrd-init] syscall smoke complete
[linux] exit status=0
QEMU smoke test OK.
```

Este smoke mantiene el arranque obligatorio con OpenSBI:

```text
qemu-system-riscv32 -M virt -m 256 -bios default -kernel build/caribe_rv32.elf
```

El 2026-05-31 quedo verificado reconocimiento de CPU desde el DTB entregado por
OpenSBI/QEMU:

```text
[XNU-CaribeOS] riscv32_kernel_entry
  hart=0 cpus=1 dtb=0x8fe00000
  cpu_isa=rv32imafdch_zic64b_zicbom_zicbop_zicboz_... mmu=riscv,sv32 compatible=riscv
  timebase=10000000 caps=0x0001803f
[initrd-init] /proc/version: Linux version 0.0.1-caribe (XNU-CaribeOS stage0) rv32imafdch_...
[initrd-init] /proc/cpuinfo:
processor	: 0
hart		: 0
isa		: rv32imafdch_zic64b_zicbom_zicbop_zicboz_...
mmu		: riscv,sv32
compatible	: riscv
[linux] exit status=0
```

Nota practica: al cambiar `riscv32_bootinfo_t`, recompilar forzado tambien
`early_print.o`; si queda con offsets viejos, la UART temprana lee el campo
equivocado y cae en una trampa de carga antes del primer banner de XNU.

El 2026-05-31 tambien quedo verificado que XNU reconoce explicitamente el
firmware OpenSBI, el loader CaribeBootX y la RAM reportada por CBX/DTB:

```text
[XNU-CaribeOS] riscv32_kernel_entry
  bootloader=CaribeBootX v=2 flags=0x00000000 args=0x802087e0
  cbx_cmd=0x80208700+0x00000038 cbx_mmap=0x80208480 count=10  hart=0 cpus=1 dtb=0x8fe00000
  timebase=10000000 caps=0x0001803f sbi_spec=0x03000000 sbi_impl=00000001:00010007 sbi_name=OpenSBI sbi_ext=0x0000007f
  loader_mem=0x80000000+0x10000000 fdt_mem=0x80000000+0x10000000
  ram0=0x80000000+0x10000000
  mmap=10 source=1 conv_pages=64952 reserved_pages=584
[initrd-init] /proc/caribeos:
bootloader	: CaribeBootX
cbx_ack		: 0x584e5541
opensbi_impl	: OpenSBI 0x00000001:0x00010007
opensbi_ext	: 0x0000007f time hsm ipi rfence srst pmu dbcn
active_mem	: 0x80000000+0x10000000
mem_pages	: total=65536 usable=64952 reserved=584
[linux] exit status=0
QEMU smoke test OK.
```

Ese flujo sigue usando exclusivamente:

```text
qemu-system-riscv32 -M virt -m 256 -bios default -kernel build/caribe_rv32.elf
```

En el siguiente tranche, XNU empezo a usar esos datos para preparar servicios
SBI reales: SRST para `halt_all_cpus`, DBCN como fallback de consola temprana,
IPI para senalizacion entre harts, y RFENCE como camino futuro de shootdown TLB
cuando haya SMP activo. La verificacion visible en `/proc/caribeos` quedo asi:

```text
opensbi_ext	: 0x0000007f time hsm ipi rfence srst pmu dbcn
sbi_runtime	: reset=yes debug_console=yes ipi=yes rfence=yes
mem_pages	: total=65536 usable=64951 reserved=585
[linux] exit status=0
QEMU smoke test OK.
```

Tambien quedo quitado otro bloque de stubs de Mach CPU/processor: `cpu_info()`,
`cpu_info_count()`, `cpu_to_processor()`, `machine_processor_is_inactive()` y
`machine_choose_processor()` ya tienen implementacion RV32 temprana. El smoke
sigue llegando a:

```text
[initrd-init] /proc/cpuinfo:
processor	: 0
hart		: 0
[linux] exit status=0
QEMU smoke test OK.
```

El siguiente avance dejo el flujo preparado para pruebas SMP controladas desde
el DTB de OpenSBI/QEMU. CaribeBootX ahora lee `/chosen/bootargs`, cuenta los
nodos CPU del DTB y pasa `ncpus` real a XNU. La prueba verificada usa:

```text
powershell -ExecutionPolicy Bypass -File scripts\qemu-rv32-sbi.ps1 -SmokeTest -Seconds 18 -Smp 2 -Append "smp-start smp-smoke"
```

Lineas clave del arranque:

```text
OpenSBI v1.7
Platform HART Count         : 2
[CaribeBootX-RV32] S-mode up. hart=0
  ncpus      = 2
[CaribeBootX] HFS+ native boot via virtio-blk
[DTB] bootargs=smp-start smp-smoke
  cbx_cmd=0x80208700+0x0000004c cbx_mmap=0x80208480 count=10  hart=0 cpus=2 dtb=0x8fe00000
[smp-smoke] attempting secondary starts cpus=2
[smp-smoke] start slot=1 hart=1
[smp-smoke] hsm hart=1 status=0
[smp-smoke] hart started
[smp-smoke] bootstage=6
[smp-smoke] secondary parked confirmed
[linux] exit status=0
QEMU smoke test OK.
```

Nota practica: para argumentos con espacios, el script de QEMU empaqueta la
lista de argumentos antes de `Start-Process`; sin eso, Windows/QEMU puede
interpretar el segundo token de `-append` como un archivo suelto.

El avance siguiente empezo stage1 como semilla real dentro del initrd. El
`newc` ahora contiene `/init`, `/etc/os-release`, `/etc/caribe-release` y
`/caribe/stage1.manifest`; XNU stage0 expone `/etc` y `/caribe` como
directorios sinteticos, y stage1 valida esas rutas con syscalls Linux:

```text
[linux-initrd] cpio entries=4
[stage1-init] CaribeOS stage1 seed under XNU-CaribeOS
[stage1-init] /proc/mounts:
initrd / initrd ro,relatime 0 0
[stage1-init] /proc/filesystems:
nodev	proc
nodev	devtmpfs
	initrd
[stage1-init] /etc/os-release:
NAME=CaribeOS
[stage1-init] /etc/caribe-release:
boot_chain=OpenSBI->CaribeBootX->XNU-CaribeOS
[stage1-init] /caribe/stage1.manifest:
stage1=initrd-userspace
[stage1-init] getdents64(/) ok
[stage1-init] getdents64(/etc) ok
[stage1-init] getdents64(/caribe) ok
[stage1-init] faccessat(/caribe/stage1.manifest) ok
[stage1-init] statx(/etc/os-release) ok
[stage1-init] stage1 smoke complete
[linux] exit status=0
QEMU smoke test OK.
```

La regresion SMP tambien quedo verificada en el mismo stage1:

```text
Platform HART Count         : 2
[smp-smoke] secondary parked confirmed
[stage1-init] stage1 smoke complete
[linux] exit status=0
QEMU smoke test OK.
```

El siguiente salto critico ya convierte stage1 en una cadena de dos programas:
`/init` valida el pseudo-VFS inicial y luego pide `execve(/bin/caribectl)`.
XNU-CaribeOS reemplaza la imagen de usuario con el ELF estatico del initrd y
retorna a user mode en la nueva entrada:

```text
[linux-initrd] cpio entry init size=0x000027d4
[linux-initrd] cpio entry bin/caribectl size=0x000017b4
[stage1-init] getdents64(/bin) ok
[stage1-init] execve(/bin/caribectl)
[linux-exec] execve path=/bin/caribectl entry=0x00020000 sp=0x7ffeff90
[stage1-caribectl] execve target reached
[stage1-caribectl] getpid ok
[stage1-caribectl] manifest after exec:
stage1=initrd-userspace
[stage1-caribectl] done
[linux] exit status=0
QEMU smoke test OK.
```

La ruta activa de stage1 ya fue promovida de prueba puntual a un userspace con
handoff normal:

```text
/init -> /sbin/init
/sbin/init -> caribed
/sbin/caribed -> alias explicito del gestor
/bin/caribectl -> herramienta instalada
```

Lineas verificadas:

```text
[linux-initrd] cpio entry init size=0x00001670
[linux-initrd] cpio entry sbin/init size=0x00002104
[linux-initrd] cpio entry sbin/caribed size=0x00002104
[linux-initrd] cpio entry bin/caribectl size=0x00001f3c
[stage1-init] CaribeOS userspace handoff
[stage1-init] exec /sbin/init
[linux-exec] execve path=/sbin/init entry=0x00020000 sp=0x7ffeff60
[stage1-caribed] CaribeOS init started
[stage1-caribed] /sbin enumerated
[stage1-caribed] /usr enumerated
[linux-clone] child record exited pid=2
[stage1-caribed] process record wait4 ok
status=bootable-stage1-initrd
[stage1-caribed] system ready
[linux] exit status=0
QEMU smoke test OK.
```

El Makefile ahora ofrece `boot_stage1` y `boot_stage1_smp`; ambos usan por
defecto el ELF full-stage0 de XNU-CaribeOS en vez del payload demo antiguo.

El stage1 ya prueba un arbol initrd derivado del CPIO. `/usr` y `/usr/lib`
no estan hardcodeados como pseudo directorios: salen de la entrada
`usr/lib/caribe.note` empaquetada en el initrd:

```text
[linux-initrd] cpio entry usr/lib/caribe.note size=0x00000041
[stage1-caribectl] getdents64(/usr) ok
[stage1-caribectl] getdents64(/usr/lib) ok
[stage1-caribectl] /usr/lib/caribe.note:
initrd-walker=cpio-derived-directories
path=/usr/lib/caribe.note
```

Tambien quedo un primer probe de control de procesos. Es deliberadamente
sintetico: `clone(SIGCHLD)` crea un hijo ya terminado para que `wait4` pueda
consumirlo, pero todavia no crea una segunda tarea real de XNU:

```text
status=execve-argv-envp-brk-initrd-walker-clone-wait-smoke
next=real fork/clone tasking, mmap/elf-interp
[linux-clone] synthetic exited child pid=2
[stage1-caribectl] clone/wait4 synthetic child ok
[stage1-caribectl] done
[linux] exit status=0
QEMU smoke test OK.
```

La misma imagen tambien pasa con OpenSBI/QEMU `virt` RV32 en SMP controlado:

```text
Platform HART Count         : 2
[smp-smoke] secondary parked confirmed
[stage1-init] execve(/bin/caribectl)
[stage1-caribectl] done
[linux] exit status=0
QEMU smoke test OK.
```

El `execve` ya no es solo salto de ELF: XNU-CaribeOS copia vectores RV32
acotados para `argv` y `envp`, reconstruye el stack Linux y el segundo binario
los lee desde su entrada inicial:

```text
status=execve-argv-envp-brk-smoke
next=initrd directory walker, fork/clone, wait, mmap/elf-interp
[stage1-init] execve(/bin/caribectl)
[linux-exec] execve path=/bin/caribectl entry=0x00020000 sp=0x7ffeff70
[stage1-caribectl] argv0: /bin/caribectl
[stage1-caribectl] argv1: --from-init
[stage1-caribectl] env0: CARIBE_STAGE=stage1
[stage1-caribectl] env1: CBX_CHAIN=OpenSBI-CaribeBootX-XNU
[stage1-caribectl] brk heap ok
[stage1-caribectl] done
[linux] exit status=0
QEMU smoke test OK.
```

El arranque ahora tambien tiene un reporte nativo de XNU-CaribeOS leido por
stage1 desde `/proc/bootlog`. Esto deja de ser solo una coleccion de mensajes:
`caribed` consulta un ABI procfs generado desde `riscv32_bootinfo` y confirma
la cadena OpenSBI -> CaribeBootX -> XNU-CaribeOS -> `/sbin/init`:

```text
[boot-report] chain OpenSBI -> CaribeBootX -> XNU-CaribeOS -> /sbin/init
[boot-report] firmware OpenSBI spec=0x03000000 impl=0x00000001:0x00010007 ext=0x0000007f
[boot-report] bootloader CaribeBootX v=2 flags=0x00000000 ack=0x584e5541
[boot-report] cpu hart=0 harts=1 isa=rv32... mmu=riscv,sv32
[boot-report] memory active=0x80000000+0x10000000 banks=1 usable_pages=64939
[boot-report] image kernel=0x80410000+0x001e3144 initrd=0x84000000+0x0000806c dtb=0x8fe00000+0x000017cc
[boot-report] devices uart=0x10000000 irq=10 plic=0x0c000000 aclint=0x02000000 virtio=8
[stage1-caribed] /proc/bootlog:
CaribeOS boot report
chain           : OpenSBI -> CaribeBootX -> XNU-CaribeOS -> /sbin/init
firmware        : OpenSBI spec=0x03000000 impl=0x00000001:0x00010007 ext=0x0000007f time hsm ipi rfence srst pmu dbcn
bootloader      : CaribeBootX v=2 flags=0x00000000 ack=0x584e5541
memory          : active=0x80000000+0x10000000 total_kb=262144 banks=1 usable_pages=64939
status          : bootable-stage1-initrd
[stage1-caribed] system ready
QEMU smoke test OK.
```

La regresion SMP conserva el mismo reporte, pero con `harts=2`, y confirma el
arranque controlado del hart secundario por OpenSBI HSM:

```text
[DTB] bootargs=smp-start smp-smoke
[boot-report] cpu hart=0 harts=2 isa=rv32... mmu=riscv,sv32
[smp-smoke] secondary parked confirmed
[stage1-caribed] /proc/bootlog:
cpu             : hart=0 harts=2 isa=rv32... mmu=riscv,sv32 compatible=riscv
[stage1-caribed] system ready
QEMU smoke test OK.
```

Logs completos capturados:

```text
build/qemu-bootlog-up.txt
build/qemu-bootlog-smp.txt
```

Tambien quedo visible el primer estado IOKit para RV32. Esta version de XNU si
usa IOKit: el arbol trae `IOStartIOKit`, `IOService`, `IORegistryEntry`,
`IOCatalogue`, `IOPlatformExpert` y libkern C++ (`OSObject`, `OSMetaClass`,
contenedores). En CaribeOS todavia no se levanta la pila C++ completa, pero
`PE_init_iokit()` ya corre y publica una semilla verificable por stage1:

```text
[iokit-stage0] PE_init_iokit: config=IOKIT state=registry-seed
[iokit-stage0] seed: IOPlatformExpertDevice, IOCPU, RAM, UART, PLIC, ACLINT, virtio-mmio
[iokit-stage0] deferred: IOService C++ runtime, IOCatalogue matching, IOKitBSDInit root matching
[stage1-caribed] /proc/iokit:
IOKit-CaribeOS stage0
xnu_tree	: xnu-2050.48.11 iokit/ + libkern/c++ present
config		: IOKIT option enabled in MASTER.riscv32
bootstrap	: PE_init_iokit calls=1 flags=0x0000003f
mach_bridge	: is_iokit_subsystem=2800 user_client_trap=stub
bsd_bridge	: IOKitBSDInit, IOFindBSDRoot, IOMedia matching deferred
registry_seed	: IOPlatformExpertDevice
registry_seed	: IOCPU boot_hart=0 harts=1 ... mmu=riscv,sv32
registry_seed	: IOMemoryBank0 base=0x80000000 size=0x10000000
registry_seed	: IOUART16550 base=0x10000000 irq=10
registry_seed	: IOPLIC base=0x0c000000 size=0x00600000
registry_seed	: IOACLINT base=0x02000000 size=0x00010000
registry_seed	: IOVirtioMMIO count=8
[stage1-caribed] system ready
QEMU smoke test OK.
```

Con SMP, la misma ruta reporta la semilla `IOCPU` con dos harts:

```text
[smp-smoke] secondary parked confirmed
[stage1-caribed] /proc/iokit:
registry_seed	: IOCPU boot_hart=0 harts=2 ... mmu=riscv,sv32
QEMU smoke test OK.
```

Logs completos de esta tanda:

```text
build/qemu-iokit-up.txt
build/qemu-iokit-smp.txt
```
