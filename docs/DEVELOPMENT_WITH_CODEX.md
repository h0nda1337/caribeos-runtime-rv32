# Development With Codex

Codex was used extensively as a development tool for the CaribeOS runtime. It
helped inspect and edit boot code, build images, operate QEMU, write semantic
assertions, analyze serial logs, maintain PowerShell tooling, preserve artifacts,
and prepare security, license, and publication audits.

## Human Direction

The project owner specified the mandatory boot chain, target architecture,
HFS+ requirements, stage plan, SMP/process gates, Bash goal, safety rules, and
publication criteria. Codex did not choose the project's legal author,
copyright owner, or license.

## Validation Practice

AI-assisted work was validated through real builds and QEMU execution rather
than marker-only claims. Evidence includes:

- OpenSBI/CaribeBootX/XNU handoff logs;
- HFS+ and virtio-blk kernel loading;
- UP and SMP Gates A-F;
- process, pmap, signal, FD, pipe, TTY, and Bash gates;
- 10,000-cycle stress and exact resource-baseline checks;
- hashes, manifests, Git bundles, restore tests, and secret scans.

Complete logs and machine audit data remain outside the public repository;
compact non-sensitive summaries are checked in.

## Review Boundary

AI use does not replace human technical, security, or legal review. CaribeBootX
privilege transitions, MMU/trap assembly, HFS+ parsing, ELF/initrd handling,
virtio descriptors, process assertions, PowerShell process cleanup, third-party
source provenance, and release packaging all warrant additional human review.

Codex is a tool used in development, not the legal author or accountable
maintainer. Future AI-assisted changes require the same focused tests and
review as any other contribution.
