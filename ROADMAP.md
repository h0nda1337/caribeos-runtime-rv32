# Roadmap

This roadmap is directional and does not promise dates. New work must preserve
the last stable semantic gate and add focused evidence.

## Publication Baseline

- finish runtime licensing, third-party source packaging, documentation, and CI;
- verify build/run instructions from clean public clones;
- publish a separate public-preview tag without moving the technical tag;
- attach a preview, corresponding source, hashes, and compact evidence.

## Boot and Storage

- harden DTB, HFS+, ELF, initrd, and virtio validation against malformed input;
- make build products independent of host drive and workspace paths;
- reduce one-off bring-up scripts and consolidate maintained tooling;
- define a filesystem path beyond read-mostly boot media.

## Userland and Processes

- broaden the Linux-compatible syscall surface only with semantic tests;
- strengthen dynamic ELF and loader behavior;
- improve terminal, process-group, session, and job-control semantics;
- make an interactive shell useful beyond the current scripted gate;
- keep userspace SMP stress and resource accounting mandatory.

## Device Model and Quality

- expand IOKit service matching and lifecycle integration with the XNU repo;
- add virtio devices incrementally with negative tests;
- improve static analysis, reproducibility, and test runtime;
- document a defensible security boundary before non-laboratory use.

Networking, broad hardware support, macOS binary compatibility, and production
readiness are not Tranche 201 features.
