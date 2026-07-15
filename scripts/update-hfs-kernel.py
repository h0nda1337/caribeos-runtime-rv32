#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

import argparse
import math
import pathlib
import struct


def be16(buf, off):
    return struct.unpack_from(">H", buf, off)[0]


def be32(buf, off):
    return struct.unpack_from(">I", buf, off)[0]


def be64(buf, off):
    return struct.unpack_from(">Q", buf, off)[0]


def put_be32(buf, off, value):
    struct.pack_into(">I", buf, off, value)


def put_be64(buf, off, value):
    struct.pack_into(">Q", buf, off, value)


def ceil_div(value, divisor):
    return (value + divisor - 1) // divisor


def ascii_name(buf, off, chars):
    out = []
    for i in range(chars):
        code = be16(buf, off + i * 2)
        out.append(chr(code) if 0 < code < 128 else "?")
    return "".join(out)


class Fork:
    def __init__(self, size, extents):
        self.size = size
        self.extents = extents

    @property
    def allocated_blocks(self):
        return sum(count for _, count in self.extents)


class HFSPlusImage:
    FREE_BLOCKS_OFF = 48
    ALLOCATION_FILE_OFF = 112
    FILE_DATA_FORK_OFF = 88

    def __init__(self, image_path):
        self.image_path = pathlib.Path(image_path)
        self.fp = self.image_path.open("r+b")
        self.block_size = 0
        self.total_blocks = 0
        self.free_blocks = 0
        self.allocation = None
        self.catalog = None
        self.node_size = 4096
        self.first_leaf = 1
        self.last_leaf = 1
        self.total_nodes = 1

    def close(self):
        self.fp.close()

    def read_at(self, off, size):
        self.fp.seek(off)
        return bytearray(self.fp.read(size))

    def write_at(self, off, data):
        self.fp.seek(off)
        self.fp.write(data)

    def fork_from(self, buf, off):
        size = be64(buf, off)
        extents = []
        for i in range(8):
            start = be32(buf, off + 16 + i * 8)
            count = be32(buf, off + 20 + i * 8)
            if count:
                extents.append((start, count))
        return Fork(size, extents)

    def mount(self):
        vh = self.read_at(1024, 512)
        sig = be16(vh, 0)
        if sig not in (0x482B, 0x4858):
            raise RuntimeError(f"bad HFS+ signature 0x{sig:04x}")

        self.block_size = be32(vh, 40)
        self.total_blocks = be32(vh, 44)
        self.free_blocks = be32(vh, self.FREE_BLOCKS_OFF)
        self.allocation = self.fork_from(vh, self.ALLOCATION_FILE_OFF)
        self.catalog = self.fork_from(vh, 272)

        node0 = self.read_fork(self.catalog, 0, 4096)
        self.first_leaf = be32(node0, 14 + 10)
        self.last_leaf = be32(node0, 14 + 14)
        self.node_size = be16(node0, 14 + 18)
        self.total_nodes = be32(node0, 14 + 22)

        if not self.node_size:
            self.node_size = 4096
        if not self.first_leaf or not self.last_leaf or self.last_leaf < self.first_leaf:
            self.first_leaf = 1
            self.last_leaf = max(1, self.total_nodes - 1)

    def read_fork(self, fork, off, size):
        out = bytearray()
        while size:
            logical_block = off // self.block_size
            in_block = off % self.block_size
            phys_block = None
            cursor = logical_block
            for start, count in fork.extents:
                if cursor < count:
                    phys_block = start + cursor
                    break
                cursor -= count
            if phys_block is None:
                raise RuntimeError("fork extent not found")

            chunk = min(size, self.block_size - in_block)
            out += self.read_at(phys_block * self.block_size + in_block, chunk)
            off += chunk
            size -= chunk
        return out

    def write_fork(self, fork, off, data):
        pos = 0
        size = len(data)
        while size:
            logical_block = off // self.block_size
            in_block = off % self.block_size
            phys_block = None
            cursor = logical_block
            for start, count in fork.extents:
                if cursor < count:
                    phys_block = start + cursor
                    break
                cursor -= count
            if phys_block is None:
                raise RuntimeError("fork extent not found")

            chunk = min(size, self.block_size - in_block)
            self.write_at(phys_block * self.block_size + in_block,
                          data[pos:pos + chunk])
            off += chunk
            pos += chunk
            size -= chunk

    def read_allocation_bitmap(self):
        if self.allocation is None or self.allocation.size == 0:
            raise RuntimeError("allocation bitmap fork not available")
        return self.read_fork(self.allocation, 0, self.allocation.size)

    @staticmethod
    def bitmap_mask(block):
        return 0x80 >> (block % 8)

    @classmethod
    def bitmap_is_used(cls, bitmap, block):
        return (bitmap[block // 8] & cls.bitmap_mask(block)) != 0

    @classmethod
    def bitmap_set_used(cls, bitmap, block, used):
        mask = cls.bitmap_mask(block)
        if used:
            bitmap[block // 8] |= mask
        else:
            bitmap[block // 8] &= (~mask & 0xFF)

    def find_free_run(self, bitmap, blocks_needed):
        run_start = None
        run_len = 0

        for block in range(self.total_blocks):
            if not self.bitmap_is_used(bitmap, block):
                if run_start is None:
                    run_start = block
                    run_len = 1
                else:
                    run_len += 1
                if run_len >= blocks_needed:
                    return run_start
            else:
                run_start = None
                run_len = 0
        raise RuntimeError(f"no free HFS+ run for {blocks_needed} blocks")

    def write_allocation_bitmap_and_header(self, bitmap, free_blocks):
        vh = self.read_at(1024, 512)
        put_be32(vh, self.FREE_BLOCKS_OFF, free_blocks)
        self.write_at(1024, vh)
        self.write_fork(self.allocation, 0, bitmap)
        self.free_blocks = free_blocks

    def scan_child(self, parent, target):
        for node_id in range(self.first_leaf, self.last_leaf + 1):
            node_off = node_id * self.node_size
            node = self.read_fork(self.catalog, node_off, self.node_size)
            if node[8] != 0xFF:
                continue

            records = be16(node, 10)
            index = self.node_size - 2 * (records + 1)
            for rec in range(records):
                rec_off = be16(node, index + rec * 2)
                key_len = be16(node, rec_off)
                rec_parent = be32(node, rec_off + 2)
                name_len = be16(node, rec_off + 6)
                name = ascii_name(node, rec_off + 8, name_len)
                data_off = rec_off + 2 + key_len

                if rec_parent != parent or name != target:
                    continue

                record_type = be16(node, data_off)
                return {
                    "node_id": node_id,
                    "node": node,
                    "node_off": node_off,
                    "data_off": data_off,
                    "record_type": record_type,
                }
        return None

    def find_file(self, path):
        parent = 2
        parts = [part for part in path.split("/") if part]
        for i, part in enumerate(parts):
            rec = self.scan_child(parent, part)
            if rec is None:
                raise RuntimeError(f"{path}: component not found: {part}")
            last = i == len(parts) - 1
            if last:
                if rec["record_type"] != 0x0002:
                    raise RuntimeError(f"{path}: final component is not a file")
                return rec
            if rec["record_type"] != 0x0001:
                raise RuntimeError(f"{path}: component is not a folder: {part}")
            parent = be32(rec["node"], rec["data_off"] + 8)
        raise RuntimeError("empty path")

    def replace_file(self, path, payload, allow_grow=False):
        rec = self.find_file(path)
        fork_off = rec["data_off"] + self.FILE_DATA_FORK_OFF
        fork = self.fork_from(rec["node"], fork_off)
        alloc = fork.allocated_blocks * self.block_size

        if len(payload) > alloc:
            if not allow_grow:
                raise RuntimeError(
                    f"{path}: payload {len(payload)} bytes exceeds allocation {alloc}")

            required_blocks = ceil_div(len(payload), self.block_size)
            bitmap = self.read_allocation_bitmap()
            new_start = self.find_free_run(bitmap, required_blocks)
            old_blocks = fork.allocated_blocks

            for block in range(new_start, new_start + required_blocks):
                self.bitmap_set_used(bitmap, block, True)
            for start, count in fork.extents:
                for block in range(start, start + count):
                    self.bitmap_set_used(bitmap, block, False)

            fork = Fork(len(payload), [(new_start, required_blocks)])
            alloc = required_blocks * self.block_size
            self.free_blocks = self.free_blocks + old_blocks - required_blocks
            self.write_allocation_bitmap_and_header(bitmap, self.free_blocks)
            print(
                f"grew {path}: moved to extent {new_start}+{required_blocks}")

        self.write_fork(fork, 0, payload)
        if len(payload) < alloc:
            zero_len = min(self.block_size, alloc - len(payload))
            self.write_fork(fork, len(payload), bytes(zero_len))

        put_be64(rec["node"], fork_off, len(payload))
        put_be32(rec["node"], fork_off + 12,
                 math.ceil(len(payload) / self.block_size))
        for i in range(8):
            put_be32(rec["node"], fork_off + 16 + i * 8, 0)
            put_be32(rec["node"], fork_off + 20 + i * 8, 0)
        for i, (start, count) in enumerate(fork.extents[:8]):
            put_be32(rec["node"], fork_off + 16 + i * 8, start)
            put_be32(rec["node"], fork_off + 20 + i * 8, count)
        self.write_fork(self.catalog, rec["node_off"], rec["node"])
        return alloc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("payload")
    parser.add_argument("--path", default="/kernel.elf")
    parser.add_argument("--allow-grow", action="store_true",
                        help="move the file to a larger free extent if needed")
    args = parser.parse_args()

    payload = pathlib.Path(args.payload).read_bytes()
    hfs = HFSPlusImage(args.image)
    try:
        hfs.mount()
        alloc = hfs.replace_file(args.path, payload, args.allow_grow)
        print(f"updated {args.path}: {len(payload)} bytes (allocated {alloc})")
    finally:
        hfs.close()


if __name__ == "__main__":
    main()
