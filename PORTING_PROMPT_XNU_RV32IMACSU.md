# Prompt para continuar CaribeOS/XNU RV32IMACSU

Estamos portando XNU/Darwin a RISC-V 32-bit, específicamente RV32IMACSU, como CaribeOS. La cadena de arranque obligatoria debe ser:

OpenSBI -> CaribeBootX -> XNU-CaribeOS

Requisitos importantes:

- OpenSBI queda como firmware M-mode y entrega control en S-mode.
- CaribeBootX corre en S-mode sobre QEMU `virt` RV32, inicializa consola UART, MMU Sv32 identidad, timer/traps mínimos y recibe el DTB de OpenSBI.
- CaribeBootX debe cargar el siguiente stage desde un disco emulado virtio-blk.
- El disco del sistema usa HFS+.
- CaribeBootX debe poder montar/leer HFS+ lo suficiente para localizar `com.apple.Boot.plist`, extraer flags como `kernel=/kernel.elf` si existen, cargar `/kernel.elf` y saltar a XNU-CaribeOS.
- Si no hay `com.apple.Boot.plist`, debe caer por defecto en `/kernel.elf`.
- El flujo mínimo verificado actualmente es: CaribeBootX -> payload HFS+ -> virtio-blk -> `hfsplus.img` -> `/kernel.elf` -> kernel demo por UART.
- Mantener compatibilidad con QEMU `qemu-system-riscv32 -M virt -m 256 -bios default`.
- No volver al modo viejo de `-bios build/caribe_rv32.bin`; ese camino ejecutaba direcciones equivocadas. El arranque correcto usa OpenSBI con `-bios default -kernel build/caribe_rv32.elf`.
- El loader HFS+ debe respetar el layout real de `HFSPlusFileRecord`; incluye el campo BSD `special` antes de `userInfo[4]`. Sin ese campo, el `dataFork` queda mal alineado y `kernel.elf` parece tener tamaño 0.
- Evitar scripts PowerShell gigantes con TCP inline porque Microsoft Defender puede clasificarlos como ClickFix. Preferir scripts claros y versionados.

Objetivo siguiente:

Convertir el payload HFS+ probado en parte nativa de CaribeBootX, de modo que CaribeBootX cargue directamente XNU-CaribeOS desde HFS+ sin depender de `bootelf` manual. Después sustituir el kernel demo por el primer entry real de XNU-CaribeOS RV32IMACSU.
