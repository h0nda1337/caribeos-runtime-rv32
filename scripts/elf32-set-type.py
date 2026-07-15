#!/usr/bin/env python3
"""Copy an ELF32 little-endian image while changing its e_type field."""

import argparse
import pathlib
import struct


ELF_MAGIC = b"\x7fELF"
ELFCLASS32 = 1
ELFDATA2LSB = 1
ET_VALUES = {
    "ET_EXEC": 2,
    "ET_DYN": 3,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("elf_type", choices=sorted(ET_VALUES))
    args = parser.parse_args()

    data = bytearray(args.input.read_bytes())
    if len(data) < 52:
        raise SystemExit(f"{args.input}: too small for ELF32")
    if data[0:4] != ELF_MAGIC or data[4] != ELFCLASS32 or data[5] != ELFDATA2LSB:
        raise SystemExit(f"{args.input}: expected ELF32 little-endian")

    struct.pack_into("<H", data, 16, ET_VALUES[args.elf_type])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
