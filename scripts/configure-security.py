#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Update the public enrollment header only when its content changes."""
import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--trust-header", default="")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
text = "/* Generated public trust enrollment; no private material. */\n"
text += "#define CARIBE_DEV_PUBLIC_KEY {0}\n"
if args.trust_header:
    source = Path(args.trust_header).read_text(encoding="ascii")
    match = re.search(r"^#define CARIBE_DEV_PUBLIC_KEY \{((?:0x[0-9a-fA-F]{2},){31}0x[0-9a-fA-F]{2})\}$",
                      source, re.MULTILINE)
    if not match:
        raise ValueError("expected the public header produced by catkey.py enroll-header")
    if all(value == "0x00" for value in match.group(1).split(",")):
        raise ValueError("zero-filled enrollment is not a public key")
    text = "/* Generated development public trust enrollment. */\n"
    text += f"#define CARIBE_DEV_PUBLIC_KEY {{{match.group(1)}}}\n"
args.output.parent.mkdir(parents=True, exist_ok=True)
if not args.output.exists() or args.output.read_text(encoding="ascii") != text:
    args.output.write_text(text, encoding="ascii")
