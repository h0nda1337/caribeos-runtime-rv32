#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

import argparse
import importlib.util
import math
import pathlib
import struct


FILE_RECORD_SIZE = 248
ROOT_PARENT_ID = 2
CATALOG_FILE_RECORD = 0x0002
VOLUME_FILE_COUNT_OFF = 32
VOLUME_NEXT_CATALOG_ID_OFF = 60


def load_hfs_helpers():
    here = pathlib.Path(__file__).resolve().parent
    helper = here / "update-hfs-kernel.py"
    spec = importlib.util.spec_from_file_location("hfs_update", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def put_be16(buf, off, value):
    struct.pack_into(">H", buf, off, value)


def put_be32(buf, off, value):
    struct.pack_into(">I", buf, off, value)


def put_be64(buf, off, value):
    struct.pack_into(">Q", buf, off, value)


def align2(value):
    return (value + 1) & ~1


def utf16be_name(name):
    out = bytearray()
    for ch in name:
        code = ord(ch)
        if code == 0 or code > 0x7f:
            raise RuntimeError(f"only ASCII HFS+ names are supported: {name}")
        out += struct.pack(">H", code)
    return out


def build_catalog_file_record(hfs, name, file_id, payload, extent):
    name_bytes = utf16be_name(name)
    key_len = 4 + 2 + len(name_bytes)
    record = bytearray()
    record += struct.pack(">H", key_len)
    record += struct.pack(">I", ROOT_PARENT_ID)
    record += struct.pack(">H", len(name))
    record += name_bytes

    data = bytearray(FILE_RECORD_SIZE)
    put_be16(data, 0, CATALOG_FILE_RECORD)
    put_be32(data, 8, file_id)
    put_be32(data, 32, 0)
    put_be32(data, 36, 0)
    put_be32(data, 40, 0o100755)
    fork_off = 88
    put_be64(data, fork_off, len(payload))
    put_be32(data, fork_off + 8, 0)
    put_be32(data, fork_off + 12, math.ceil(len(payload) / hfs.block_size))
    put_be32(data, fork_off + 16, extent[0])
    put_be32(data, fork_off + 20, extent[1])
    record += data
    if len(record) % 2:
        record += b"\0"
    return record


def create_root_file(image, path, payload):
    hmod = load_hfs_helpers()
    hfs = hmod.HFSPlusImage(image)
    hfs.mount()
    try:
        name = path.strip("/")
        if "/" in name or not name:
            raise RuntimeError("this helper only creates files in the HFS+ root")
        try:
            hfs.find_file("/" + name)
        except RuntimeError:
            pass
        else:
            raise RuntimeError(f"/{name} already exists; use update-hfs-kernel.py --path")

        blocks_needed = math.ceil(len(payload) / hfs.block_size)
        bitmap = hfs.read_allocation_bitmap()
        start = hfs.find_free_run(bitmap, blocks_needed)
        for block in range(start, start + blocks_needed):
            hfs.bitmap_set_used(bitmap, block, True)
        hfs.write_allocation_bitmap_and_header(
            bitmap, hfs.free_blocks - blocks_needed)

        hfs.write_at(start * hfs.block_size, payload)
        padding = blocks_needed * hfs.block_size - len(payload)
        if padding:
            hfs.write_at(start * hfs.block_size + len(payload),
                         bytes(min(padding, hfs.block_size)))

        vh = hfs.read_at(1024, 512)
        file_id = hmod.be32(vh, VOLUME_NEXT_CATALOG_ID_OFF)
        if file_id < 20:
            file_id = 20
        put_be32(vh, VOLUME_FILE_COUNT_OFF,
                 hmod.be32(vh, VOLUME_FILE_COUNT_OFF) + 1)
        put_be32(vh, VOLUME_NEXT_CATALOG_ID_OFF, file_id + 1)
        hfs.write_at(1024, vh)

        node_id = hfs.first_leaf
        node_off = node_id * hfs.node_size
        node = hfs.read_fork(hfs.catalog, node_off, hfs.node_size)
        if node[8] != 0xff:
            raise RuntimeError("first catalog leaf is not a leaf node")
        records = hmod.be16(node, 10)
        old_index = hfs.node_size - 2 * (records + 1)
        table = [hmod.be16(node, old_index + i * 2)
                 for i in range(records + 1)]
        free_off = table[0]
        new_record = build_catalog_file_record(
            hfs, name, file_id, payload, (start, blocks_needed))
        new_off = align2(free_off)
        new_free = new_off + len(new_record)
        new_index = hfs.node_size - 2 * (records + 2)
        if new_free > new_index:
            raise RuntimeError("not enough free space in catalog leaf")

        node[new_off:new_off + len(new_record)] = new_record
        put_be16(node, 10, records + 1)
        new_table = [new_free, new_off] + table[1:]
        for i, off in enumerate(new_table):
            put_be16(node, new_index + i * 2, off)
        hfs.write_fork(hfs.catalog, node_off, node)
        print(
            f"created /{name}: {len(payload)} bytes extent {start}+{blocks_needed} fileID={file_id}")
    finally:
        hfs.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("path")
    parser.add_argument("payload")
    args = parser.parse_args()

    create_root_file(args.image, args.path, pathlib.Path(args.payload).read_bytes())


if __name__ == "__main__":
    main()
