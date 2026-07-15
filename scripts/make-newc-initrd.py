#!/usr/bin/env python3
import argparse
import pathlib
import stat


def align4(value):
    return (value + 3) & ~3


def newc_header(name, data, mode, ino):
    fields = [
        ino,
        mode,
        0,
        0,
        1,
        0,
        len(data),
        0,
        0,
        0,
        0,
        len(name) + 1,
        0,
    ]
    return ("070701" + "".join(f"{field:08x}" for field in fields)).encode("ascii")


def append_entry(out, name, data, mode, ino):
    out += newc_header(name, data, mode, ino)
    out += name.encode("utf-8") + b"\0"
    out += b"\0" * (align4(len(out)) - len(out))
    out += data
    out += b"\0" * (align4(len(out)) - len(out))
    return out


def parse_entry(spec):
    if "=" not in spec:
        raise SystemExit(f"entry must be name=path: {spec}")
    name, path = spec.split("=", 1)
    name = name.lstrip("/")
    if not name:
        raise SystemExit("entry name cannot be empty")
    return name, pathlib.Path(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("entries", nargs="+", help="newc entry as name=host_path")
    args = parser.parse_args()

    out = bytearray()
    ino = 1
    for spec in args.entries:
        name, path = parse_entry(spec)
        data = path.read_bytes()
        out = append_entry(out, name, data, stat.S_IFREG | 0o755, ino)
        ino += 1
    out = append_entry(out, "TRAILER!!!", b"", 0, ino)

    output = pathlib.Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(out)
    print(f"wrote {output}: {len(out)} bytes")


if __name__ == "__main__":
    main()
