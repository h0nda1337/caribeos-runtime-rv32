# Native Shared-Area Evidence

Recorded 2026-10-13. Kernel SHA-256:
`bef8795f430f4a27cb6e76052b2c8e703690d4d089ea384f195422bcd53aac1f`.
This verifies native XNU shared memory for Syllable, not a complete AppServer,
Desktop, Dock or FileBrowser. No Wayland/X11 implementation provides any part
of the tested IPC, mappings, input or display transport.

| Case | Areas | Ports | Graphics/input | Private VM/Bash |
| --- | --- | --- | --- | --- |
| OpenSBI UP | A-E, 10,000 shared exchanges | A-D, 10,000 exchanges | A-E, restart | PASS |
| OpenSBI SMP2, RV32IMAC base without F/D/H | A-E, 10,000 shared exchanges | A-D, 10,000 exchanges | A-E, restart | PASS |
| SecureSBI SMP2 | A-E, 10,000 shared exchanges | A-D, 10,000 exchanges | A-E, restart | PASS |

Each result records ten artifact hashes and six QMP scanouts. `00-shared-area`
is a child-rendered framebuffer presented by its parent from shared physical
pages. Five deterministic pixels are checked automatically. Other scanouts
exercise the genuine previously ported Syllable decorators, not a substitute
desktop. SMP cases require kernel Gate F, while these GUI/IPC processes remain
on CPU0; this is not a cross-hart userspace or native-thread stress claim.

Area tests cover 32 objects, 64 views, all 1024 pages, explicit exhaustion,
fork rollback, 256 zeroed recycle cycles, same-ID/same-VA fork inheritance,
independent exec, failed exec preservation, successful exec revocation,
creator deletion with live clones, exit cleanup, read-only copyout rejection,
protection escalation rejection, reserved-VA guards and create-copyout rollback.
The implementation is bounded wired memory, not a full pageable area system.

The same kernel passed process gates 1-15, Gate 15 SMP stability and all 17
CaribeSecurity QEMU cases. CatKey host tests: 14 PASS. Regression summaries
and the security result are retained separately; old Tranche 201 evidence
and the earlier v0.2 IPC results are unchanged. No new Release was created.

Forced recompilation of native_area/native_ipc/linux_exec/linux_syscall and
relinking reproduced the exact kernel SHA above. Forced runtime adapter/probe
rebuild reproduced all four hashes in `rebuild.json`, including the native
archive and initrd. This is incremental rebuild reproducibility, not proof of
a clean-host toolchain rebuild. No ELF, disk image, external source tree or
private signing material is committed here. The source manifest retains the
original LGPL notices and distinguishes Message code that is not yet compiled.
