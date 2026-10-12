#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Fetch immutable upstream crypto sources without tracking or relicensing them."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    lock = json.loads((ROOT / "security/dependencies.json").read_text())
    for name, dep in lock.items():
        path = ROOT / "third_party" / dep["directory"]
        if not path.exists():
            subprocess.run(["git", "-c", "core.autocrlf=false", "clone", "--depth", "1", "--branch", dep["tag"],
                            dep["url"], str(path)], check=True)
        actual = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
        if actual != dep["commit"]:
            raise RuntimeError(f"{name}: unexpected upstream commit {actual}")
        # Windows Git and MSYS Git can disagree about checkout CRLF conversion.
        subprocess.run(["git", "-C", str(path), "diff", "--ignore-cr-at-eol",
                        "--quiet", "HEAD"], check=True)
        print(f"{name}: pinned source verified {actual}")


if __name__ == "__main__":
    main()
