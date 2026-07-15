# Security Policy

CaribeOS is experimental research software. It has not received a production
security review and must not protect sensitive workloads or process untrusted
disk images, initrds, DTBs, devices, or user input.

Report suspected vulnerabilities through GitHub private vulnerability
reporting for `h0nda1337/caribeos-runtime-rv32`. Include the affected commit or
tag, QEMU command, artifact hashes, minimal reproducer, and relevant serial log.
If private reporting is unavailable, contact the repository owner through the
methods listed on their GitHub profile before disclosing details.

Do not submit credentials, keys, private disk images, proprietary Apple
material, local machine configuration, or unrelated logs. There is no response
SLA, and only the latest published preview is considered for fixes.

The current security boundary excludes:

- hostile multi-user isolation and production syscall validation;
- untrusted HFS+, initrd, FDT, ELF, or virtio input;
- networking and remote service exposure;
- secure boot, code signing, trusted update delivery, and rollback protection;
- side-channel resistance and broad hardware threat modeling.

Public issues may discuss a vulnerability only after sensitive details are
removed and coordinated disclosure is complete.
