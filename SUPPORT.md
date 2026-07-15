# Support

CaribeOS is maintained as research software on a best-effort basis. It has no
support SLA, production support, physical-hardware compatibility program, or
support from Apple.

The supported reference surface is QEMU `virt` RV32, QEMU-provided OpenSBI,
256 MiB RAM, and one or two harts. Use GitHub issues for reproducible bugs and
focused feature proposals. Include:

- runtime and XNU commits/tags;
- `testproject.ps1` mode and full QEMU command;
- host/tool versions, CPU count, and RAM size;
- kernel, CaribeBootX, initrd, and disk hashes when relevant;
- the smallest serial excerpt that demonstrates the failure;
- whether UP, SMP, or both reproduce it.

Remove credentials, personal paths, private images, and unrelated logs. Report
security-sensitive behavior through `SECURITY.md`.

Requests for macOS compatibility, production deployment guidance, unsupported
hardware, or Apple product support are outside scope.
