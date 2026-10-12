# CaribeOS Hypervisor: Contract Only

No hypervisor, guest boot, guest memory isolation, or VS-mode test is
implemented in this phase. Existing XNU still runs in S-mode; RV32IMACSU
does not imply the H extension. SecureSBI/CBX must work without H. This is
an original design, not a port of proprietary Xbox code.

The [RISC-V privileged H specification](https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/hypervisor.adoc)
defines HS-mode, VS-mode, virtual interrupt state, and two-stage translation.
RV32 guest-stage Sv32x4 requires a 16 KiB root page table and appropriate
HFENCE operations. Ordinary Sv32 and remote SFENCE alone are not guest
translation isolation. H presence must be discovered and verified before
using hypervisor CSRs; absence must leave the current boot path unchanged.

## Future Optional Chain

```text
SecureSBI (M) -> CaribeBootX (S/HS) -> CaribeHypervisor (HS) -> XNU (VS)
```

The hypervisor binary requires its own verified-image role/permission in a
future CatKey version. It must not use the kernel permission implicitly.
It owns guest physical mappings, vCPU state, timer/interrupt virtualization,
resource quotas, and all guest SBI mediation. Host memory, firmware RAM,
keys, and evidence buffers are excluded from guest stage-2 mappings.

`include/uapi/caribe_hypervisor.h` defines a 48-byte, version-1 guest config:
version, size, flags, guest ID; physical RAM base/size, vCPU count, reserved
zero; entry, DTB, evidence address/size. This is a future internal contract,
not a callable SBI service or a host launcher today. Inputs must be checked
for overflow, alignment, ownership, limits, and overlap before any mapping.
No key material belongs in the configuration or guest DTB.

## Guest Firmware Policy

Guest ECALLs terminate at HS and must not be blindly forwarded to M-mode.
Default CaribeSSBI mediation returns DENIED for every operation, including
discovery (`caribe_hv_guest_cssbi_result`). A future allowlist may expose
guest-scoped nonsecret metadata; host signing, enrollment, attestation, and
policy mutation remain denied. Host identity must never become guest identity.

SecureSBI additionally rejects requests whose saved MSTATUS indicates MPV.
This defense is compiled and normal host calls are tested, but no real VS
guest exercised it yet. A malicious/compromised HS host can forge its own
host request, so MPV checking does not authenticate the host or replace
hardware domain policy. Standard SBI behavior is retained.

## Required Future Gates

1. Explicit H detection, no-H fallback, and controlled HS CSR setup.
2. One guest vCPU with isolated Sv32x4 mappings and intentional fault tests.
3. Guest ECALL mediation and actual CSSBI DENIED tests from VS-mode.
4. Virtual timers/IPIs and complete vCPU context preservation.
5. Remote HFENCE and stale guest translation negative tests.
6. Verified hypervisor image and authenticated host evidence where hardware permits.

All guest execution/isolation gates above are NOT_RUN. The current no-H boot
test only verifies that the existing ordinary S-mode chain does not require H.
