#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

"""Dependency-free public-tree checks shared by local validation and CI."""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

KERNEL_SHA256 = "c63fe4bfbaeaf674a4092c1c579cfe472fc433d2e89b4f55307484ed820e595e"
RUNTIME_LICENSE_SHA256 = "5ffd33642047c8ef252ef27242afea5ef8348ff99e3dfc1a6f3a79f0de6883ea"
RUNTIME_COPYRIGHT = "Copyright (c) 2026 h0nda1337"
RUNTIME_SPDX = "SPDX-License-Identifier: BSD-2-Clause"
EXPECTED_TAG_TARGETS = {
    "xnu": "bf82ffc9849024fb38c99e1c2ed49961b82e9f4e",
    "runtime": "406f910d06891f30c866d284fbc98bde83f94e35",
}
REQUIRED = {
    "xnu": [
        "README.md", "ARCHITECTURE.md", "BUILDING.md", "TESTING.md", "RESTORE.md",
        "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md",
        "ROADMAP.md", "CITATION.cff", "NOTICE.md", "THIRD_PARTY.md",
        "APPLE_LICENSE", "docs/PORT_STATUS.md", "docs/TRANCHE_201_RELEASE_NOTES.md",
        "docs/TRANCHE_201_EVIDENCE.md", "docs/PUBLIC_LICENSE_REVIEW.md",
        "docs/PUBLIC_SECURITY_AUDIT.md", "docs/DEVELOPMENT_WITH_CODEX.md",
        "docs/REPRODUCIBILITY_REPORT.md",
    ],
    "runtime": [
        "README.md", "BUILDING.md", "RUNNING_QEMU.md", "TESTING.md", "RESTORE.md",
        "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md",
        "ROADMAP.md", "CITATION.cff", "LICENSE", "NOTICE.md", "THIRD_PARTY.md",
        "docs/BOOT_CHAIN.md", "docs/DEVELOPER_PREVIEW.md",
        "docs/TRANCHE_201_RELEASE_NOTES.md", "docs/TRANCHE_201_EVIDENCE.md",
        "docs/PUBLIC_LICENSE_REVIEW.md", "docs/PUBLIC_SECURITY_AUDIT.md",
        "docs/DEVELOPMENT_WITH_CODEX.md", "docs/REPRODUCIBILITY_REPORT.md",
        "docs/RUNTIME_LICENSE_SCOPE.json",
    ],
}
GENERATED_PREFIXES = {
    "xnu": ("BUILD/",),
    "runtime": ("build/", "third_party/"),
}
GENERATED_SUFFIXES = (
    ".o", ".obj", ".a", ".so", ".elf", ".bin", ".img", ".iso", ".dtb",
    ".map", ".log", ".pyc", ".pyo", ".zip", ".tar.gz", ".tar.xz",
)
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def tracked_files(root: Path) -> list[str]:
    raw = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    return [item.decode("utf-8") for item in raw.split(b"\0") if item]


def validate_docs(root: Path, kind: str, tracked: list[str], errors: list[str]) -> None:
    for relative in REQUIRED[kind]:
        path = root / relative
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"missing or empty required file: {relative}")

    disclaimer = (
        "CaribeOS is an independent experimental project. It is not affiliated "
        "with, endorsed by, or supported by Apple Inc."
    )
    combined = "\n".join(
        (root / name).read_text(encoding="utf-8", errors="replace")
        for name in ("README.md", "NOTICE.md")
        if (root / name).is_file()
    )
    if disclaimer not in " ".join(combined.split()):
        errors.append("required Apple non-affiliation disclaimer is missing")

    for relative in tracked:
        if not relative.lower().endswith(".md"):
            continue
        source = root / relative
        text = source.read_text(encoding="utf-8", errors="replace")
        for match in LINK_RE.finditer(text):
            target = match.group(1).strip().strip("<>")
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target = unquote(target.split("#", 1)[0].split("?", 1)[0])
            if not target:
                continue
            destination = (source.parent / target).resolve()
            try:
                destination.relative_to(root.resolve())
            except ValueError:
                errors.append(f"{relative}: local link escapes repository: {target}")
                continue
            if not destination.exists():
                errors.append(f"{relative}: broken local link: {target}")

    for relative in tracked:
        if not relative.lower().endswith(".json"):
            continue
        try:
            json.loads((root / relative).read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"{relative}: invalid JSON: {exc}")

    for relative in tracked:
        if not relative.lower().endswith(".plist"):
            continue
        try:
            with (root / relative).open("rb") as stream:
                plistlib.load(stream)
        except Exception as exc:
            errors.append(f"{relative}: invalid property-list manifest: {exc}")

    citation = root / "CITATION.cff"
    if citation.is_file():
        text = citation.read_text(encoding="utf-8", errors="replace")
        for field in ("cff-version:", "title:", "authors:", "repository-code:"):
            if field not in text:
                errors.append(f"CITATION.cff: missing field {field}")


def validate_tree(root: Path, kind: str, tracked: list[str], errors: list[str]) -> None:
    prefixes = GENERATED_PREFIXES[kind]
    for relative in tracked:
        normalized = relative.replace("\\", "/")
        lower = normalized.lower()
        path = root / relative
        if normalized.startswith(prefixes) or lower.endswith(GENERATED_SUFFIXES):
            errors.append(f"generated artifact is tracked: {normalized}")
        if path.is_file() and path.stat().st_size > 50 * 1024 * 1024:
            errors.append(f"tracked file exceeds 50 MiB: {normalized}")
        if re.search(r"(^|/)(\.env($|\.)|.*\.(pem|p12|pfx|key)$)", lower):
            errors.append(f"sensitive filename is tracked: {normalized}")

    if kind == "runtime":
        clutter = re.compile(
            r"(^|/)([^/]+\.bak\.|patch_[^/]+\.sh$|fix_[^/]+\.sh$|"
            r"show_[^/]+\.sh$|debug_[^/]+\.sh$|scan_[^/]+\.sh$|"
            r"PORTING_PROMPT_XNU_RV32IMACSU\.md$|.*paliativo.*$)"
        )
        for relative in tracked:
            if clutter.search(relative):
                errors.append(f"obsolete bring-up artifact is tracked: {relative}")

    tag_target = git(root, "rev-parse", "tranche-201-stage2-complete^{}").strip()
    if tag_target != EXPECTED_TAG_TARGETS[kind]:
        errors.append(
            f"technical tag moved: expected {EXPECTED_TAG_TARGETS[kind]}, got {tag_target}"
        )

    evidence = (
        root / "docs/evidence/tranche-201/summary.txt"
        if kind == "xnu"
        else root / "docs/evidence/tranche-201/kernel.sha256"
    )
    if not evidence.is_file() or KERNEL_SHA256 not in evidence.read_text(
        encoding="utf-8", errors="replace"
    ):
        errors.append("preserved kernel SHA-256 evidence is missing or changed")

    if kind == "xnu":
        license_text = (root / "APPLE_LICENSE").read_text(
            encoding="utf-8", errors="strict"
        )
        normalized = license_text.replace("\r\n", "\n").replace("\r", "\n")
        digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        expected = "e5881019d8766c1e88a5fe1dbca4ba40c78011d41fcb18f6e9f50df60182685b"
        if digest != expected:
            errors.append(f"APPLE_LICENSE normalized SHA-256 changed: {digest}")
    else:
        validate_runtime_license(root, tracked, errors)


def runtime_code_candidates(tracked: list[str]) -> set[str]:
    extensions = {".c", ".h", ".s", ".ld", ".sh", ".py", ".ps1"}
    candidates: set[str] = set()
    for relative in tracked:
        normalized = relative.replace("\\", "/")
        suffix = Path(normalized).suffix.lower()
        if suffix in extensions or normalized == "Makefile":
            candidates.add(normalized)
        elif normalized == "userland/stage1/usr/bin/dynamic-script":
            candidates.add(normalized)
        elif normalized.startswith(".github/workflows/") and suffix in {".yml", ".yaml"}:
            candidates.add(normalized)
    return candidates


def validate_runtime_license(root: Path, tracked: list[str], errors: list[str]) -> None:
    license_path = root / "LICENSE"
    if license_path.is_file():
        license_text = license_path.read_text(encoding="utf-8", errors="strict")
        normalized = license_text.replace("\r\n", "\n").replace("\r", "\n")
        digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        if digest != RUNTIME_LICENSE_SHA256:
            errors.append(f"runtime BSD-2-Clause LICENSE changed: {digest}")

    scope_path = root / "docs/RUNTIME_LICENSE_SCOPE.json"
    try:
        scope = json.loads(scope_path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"cannot read runtime license scope: {exc}")
        return

    decision = scope.get("ownerDecision", {})
    expected_decision = {
        "approvedByGitHubAccount": "h0nda1337",
        "copyright": RUNTIME_COPYRIGHT,
        "spdxLicenseIdentifier": "BSD-2-Clause",
        "scope": "Original CaribeOS runtime code only",
    }
    for field, expected in expected_decision.items():
        if decision.get(field) != expected:
            errors.append(f"runtime license scope has invalid {field!r}")

    licensed_list = scope.get("licensedCodeFiles", [])
    excluded_records = scope.get("excludedCodeFiles", [])
    if not isinstance(licensed_list, list) or not all(
        isinstance(item, str) for item in licensed_list
    ):
        errors.append("runtime license allowlist is not a string array")
        return
    if not isinstance(excluded_records, list) or not all(
        isinstance(item, dict) and isinstance(item.get("path"), str)
        for item in excluded_records
    ):
        errors.append("runtime license exclusions are not structured path records")
        return

    licensed = {item.replace("\\", "/") for item in licensed_list}
    excluded = {item["path"].replace("\\", "/") for item in excluded_records}
    if len(licensed) != len(licensed_list):
        errors.append("runtime license allowlist contains duplicate paths")
    if len(excluded) != len(excluded_records):
        errors.append("runtime license exclusions contain duplicate paths")
    if licensed & excluded:
        errors.append("runtime files appear in both the allowlist and exclusions")

    tracked_set = {item.replace("\\", "/") for item in tracked}
    candidates = runtime_code_candidates(tracked)
    classified = licensed | excluded
    for relative in sorted(candidates - classified):
        errors.append(f"runtime code lacks an explicit license classification: {relative}")
    for relative in sorted(classified - candidates):
        errors.append(f"runtime license scope classifies a non-code path: {relative}")
    for relative in sorted(classified - tracked_set):
        errors.append(f"runtime license scope references an untracked path: {relative}")

    third_party = sorted(
        item for item in tracked_set if item == "third_party" or item.startswith("third_party/")
    )
    for relative in third_party:
        errors.append(f"third-party build material is tracked: {relative}")

    for relative in sorted(licensed & tracked_set):
        text = (root / relative).read_text(encoding="utf-8", errors="strict")
        first_lines = text.splitlines()[:8]
        copyright_lines = [line for line in first_lines if RUNTIME_COPYRIGHT in line]
        spdx_lines = [line for line in first_lines if RUNTIME_SPDX in line]
        if len(copyright_lines) != 1:
            errors.append(f"runtime copyright header is missing or duplicated: {relative}")
        if len(spdx_lines) != 1:
            errors.append(f"runtime SPDX header is missing or duplicated: {relative}")

    for relative in sorted(excluded & tracked_set):
        text = (root / relative).read_text(encoding="utf-8", errors="strict")
        if RUNTIME_COPYRIGHT in text or RUNTIME_SPDX in text:
            errors.append(f"excluded runtime file carries the project header: {relative}")

    required_boundaries = {
        "NOTICE.md": (
            "BSD-2-Clause", "APSL 2.0", "GPL-3.0-or-later", "MIT-style",
            "OpenSBI", "QEMU", "does not relicense",
        ),
        "THIRD_PARTY.md": (
            "BSD-2-Clause", "APSL 2.0", "GPL-3.0-or-later", "MIT-style",
            "OpenSBI", "QEMU", "does not relicense",
        ),
    }
    for relative, tokens in required_boundaries.items():
        text = (root / relative).read_text(encoding="utf-8", errors="strict")
        for token in tokens:
            if token not in text:
                errors.append(f"{relative}: missing license boundary {token!r}")

    review = (root / "docs/PUBLIC_LICENSE_REVIEW.md").read_text(
        encoding="utf-8", errors="strict"
    )
    if not re.search(r"(?m)^\*\*Technical review status: PASS\*\*$", review):
        errors.append("runtime public license review is not PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", choices=("xnu", "runtime"), required=True)
    parser.add_argument("--docs-only", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    tracked = tracked_files(root)
    errors: list[str] = []
    validate_docs(root, args.kind, tracked, errors)
    if not args.docs_only:
        validate_tree(root, args.kind, tracked, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"public-tree validation failed with {len(errors)} error(s)", file=sys.stderr)
        return 1

    mode = "documentation" if args.docs_only else "full static"
    print(f"{mode} validation PASS: {args.kind}, {len(tracked)} tracked files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
