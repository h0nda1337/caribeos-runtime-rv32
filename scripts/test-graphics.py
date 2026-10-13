#!/usr/bin/env python3
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
"""Actual QEMU graphics/input gates. Owns and terminates only its child QEMU."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import socket
import subprocess
import struct
import time
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent.parent
IMACSU_CPU = "rv32,f=false,d=false,h=false,zfa=false"
RUN_RESULT_PATH = None

def guest_failure(text):
    markers = ("fatal user signal", "[native-ipc] FAIL", "[native-area] FAIL",
               "[native-cxx] FAIL", "[syllable-string] FAIL", "[syllable-message] FAIL",
               "[native-sync] FAIL", "[freetype] FAIL")
    return ("panic" in text.lower() or "unexpected trap" in text.lower()
            or any(marker in text for marker in markers)
            or bool(re.search(r"\[smp-gate-[a-f]\][^\r\n]* FAIL", text)))

def scanout_fnv(image):
    value = 2166136261
    data = image.convert("RGB").tobytes()
    for offset in range(0, len(data), 3):
        red, green, blue = data[offset:offset + 3]
        value = ((value ^ ((red << 16) | (green << 8) | blue)) * 16777619) & 0xffffffff
    return value


def verify_font_elf(path):
    data = path.read_bytes()
    if (len(data) < 52 or data[:7] != b"\x7fELF\x01\x01\x01"
            or struct.unpack_from("<HH", data, 16) != (2, 243)
            or struct.unpack_from("<I", data, 36)[0] & 6):
        raise RuntimeError("FreeType probe must be static RV32 ELF/soft-float")
    offset = struct.unpack_from("<I", data, 28)[0]
    size, count = struct.unpack_from("<HH", data, 42)
    if not count or size != 32 or offset + size * count > len(data):
        raise RuntimeError("invalid FreeType ELF program headers")
    if any(struct.unpack_from("<I", data, offset + i * size)[0] in (2, 3) for i in range(count)):
        raise RuntimeError("FreeType probe cannot depend on a dynamic loader")


def build_hashes(native_cxx=False, syllable_string=False, syllable_message=False, native_sync=False, freetype=False):
    files = {
        "xnu": WORKSPACE / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
        "cbx": ROOT / "build/caribe_rv32.elf",
        "initrd": ROOT / ("build/initrd-fonts.img" if freetype else
                          "build/initrd-sync.img" if native_sync else
                          "build/initrd-message.img" if syllable_message else
                          "build/initrd-syllable.img" if syllable_string else
                          "build/initrd-cxx.img" if native_cxx else "build/initrd.img"),
        "syllableComponent": ROOT / "build/syllable-component.elf",
        "syllableLibrary": ROOT / "build/libcaribe-syllable-decorator.a",
        "sessionManager": ROOT / "build/caribe-session.elf",
        "privateVmProbe": ROOT / "build/private-vm-probe.elf",
    }
    return {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}

def verify_abi():
    kernel = WORKSPACE / "xnu-2050.48.11/osfmk/riscv32/graphics.h"
    user = ROOT / "include/uapi/caribe_graphics.h"
    def declarations(path):
        return path.read_text().split("#ifndef CARIBE_GRAPHICS_ABI_H", 1)[1].split("#endif", 1)[0]
    if declarations(kernel) != declarations(user):
        raise RuntimeError("kernel/userspace graphics ABI headers differ")

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

class Qmp:
    def __init__(self, port):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=10)
        self.file = self.socket.makefile("rwb")
        greeting = json.loads(self.file.readline())
        if "QMP" not in greeting:
            raise RuntimeError("not a QMP endpoint")
        self.sequence = 0
        self.call("qmp_capabilities")
    def call(self, command, **args):
        self.sequence += 1
        request = {"execute": command, "id": self.sequence}
        if args:
            request["arguments"] = args
        self.file.write(json.dumps(request).encode() + b"\n")
        self.file.flush()
        while True:
            response = json.loads(self.file.readline())
            if response.get("id") != self.sequence:
                continue
            if "error" in response:
                raise RuntimeError(response["error"])
            return response["return"]
    def close(self):
        self.file.close()
        self.socket.close()

def main():
    global RUN_RESULT_PATH
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--smp", type=int, choices=(1, 2), default=1)
    parser.add_argument("--bios", default="default")
    parser.add_argument("--cpu", default="", help="Optional QEMU CPU configuration")
    parser.add_argument("--native-ipc", action="store_true", help="Run native Syllable port gates before graphics")
    parser.add_argument("--native-areas", action="store_true", help="Run real shared-area gates and native IPC before graphics")
    parser.add_argument("--native-cxx", action="store_true", help="Run GNU C++/musl gates plus native areas and IPC")
    parser.add_argument("--syllable-string", action="store_true", help="Run genuine Syllable String plus C++/IPC/area gates")
    parser.add_argument("--syllable-message", action="store_true", help="Run genuine bounded Message data core plus String/C++/IPC/area gates")
    parser.add_argument("--native-sync", action="store_true", help="Run native XNU counting semaphore gates progressively")
    parser.add_argument("--sync-gate", choices=tuple("ABCDE"), default="E", help="Last semaphore gate to run")
    parser.add_argument("--freetype", action="store_true", help="Run genuine FreeType RV32-musl font gates")
    parser.add_argument("--font-gate", choices=tuple("ABCD"), default="D", help="Last font gate to run")
    parser.add_argument("--visible", action="store_true")
    parser.add_argument("--live", action="store_true", help="Open the real QEMU session; close its window to stop")
    parser.add_argument("--live-seconds", type=float, default=0,
                        help="Optional positive live-preview duration; zero waits for window close")
    args = parser.parse_args()
    args.syllable_string = args.syllable_string or args.syllable_message
    args.native_cxx = args.native_cxx or args.syllable_string
    args.native_areas = args.native_areas or args.native_cxx or args.native_sync or args.freetype
    args.native_ipc = args.native_ipc or args.native_areas
    if args.live_seconds < 0 or (args.live_seconds and not args.live):
        parser.error("--live-seconds requires --live and a nonnegative duration")
    name = ("opensbi" if args.bios == "default" else "securesbi") + f"-smp{args.smp}"
    if args.cpu:
        name += "-imacsu" if args.cpu == IMACSU_CPU else "-custom-cpu"
    if args.live:
        name += "-live"
    if args.native_sync:
        name += f"-native-sync-{args.sync_gate.lower()}"
    if args.freetype:
        name += f"-freetype-{args.font_gate.lower()}"
    if args.syllable_message:
        name += "-syllable-message"
    elif args.syllable_string:
        name += "-syllable-string"
    elif args.native_cxx:
        name += "-native-cxx"
    elif args.native_areas:
        name += "-native-areas"
    elif args.native_ipc:
        name += "-native-ipc"
    out = ROOT / "build/graphics-tests" / name
    out.mkdir(parents=True, exist_ok=True)
    result_path = out / "result.json"
    RUN_RESULT_PATH = result_path
    result_path.write_text(json.dumps({"result": "RUNNING", "smp": args.smp,
                          "bios": args.bios, "live": args.live}, indent=2) + "\n")
    verify_abi()
    artifacts = build_hashes(args.native_cxx, args.syllable_string, args.syllable_message, args.native_sync, args.freetype)
    if args.freetype:
        verify_font_elf(ROOT / "build/freetype-probe.elf")
        for name, filename in (("freetypeProbe", "build/freetype-probe.elf"),
                               ("freetypeLibrary", "build/freetype-rv32-sysroot/usr/lib/libfreetype.a"),
                               ("fontSources", "build/font-sources.json")):
            artifacts[name] = hashlib.sha256((ROOT / filename).read_bytes()).hexdigest()
    if args.native_sync:
        artifacts["nativeSyncProbe"] = hashlib.sha256((ROOT / "build/native-sync-probe.elf").read_bytes()).hexdigest()
        kernel = WORKSPACE / "xnu-2050.48.11/osfmk/riscv32/native_sync.h"
        user = ROOT / "include/uapi/caribe_sync.h"
        def sync_declarations(path):
            return path.read_text().split("#ifndef CARIBE_NATIVE_SYNC_H", 1)[1].split("#ifdef KERNEL", 1)[0].strip().removesuffix("#endif").strip()
        if sync_declarations(kernel) != sync_declarations(user):
            raise RuntimeError("native semaphore kernel/userspace ABI mismatch")
    if args.syllable_message:
        for name, filename in (("syllableMessageProbe", "syllable-message-probe.elf"),
                               ("syllableMessageLibrary", "libcaribe-syllable-message.a"),
                               ("syllableMessageSources", "syllable-message/sources.json")):
            artifacts[name] = hashlib.sha256((ROOT / "build" / filename).read_bytes()).hexdigest()
        definitions = subprocess.check_output(["riscv64-unknown-elf-nm", "-C", "--defined-only",
                          str(ROOT / "build/libcaribe-syllable-message.a")], text=True)
        if any(name in definitions for name in ("Message::SendReply", "Message::ReturnAddress", "Message::AddVariant", "Message::FindVariant")):
            raise RuntimeError("unexpected full Message/Looper profile; native thread gates required")
    if args.syllable_string:
        for name, filename in (("syllableStringProbe", "syllable-string-probe.elf"),
                               ("syllableStringLibrary", "libcaribe-syllable-string.a"),
                               ("syllableStringSources", "syllable-string/sources.json")):
            artifacts[name] = hashlib.sha256((ROOT / "build" / filename).read_bytes()).hexdigest()
    if args.native_cxx:
        for name, path in (("nativeCxxProbe", "build/cxx-runtime-probe.elf"),
                           ("gnuLibstdcxx", "build/cxx-rv32-sysroot/usr/lib/rv32imac/ilp32/libstdc++.a")):
            artifacts[name] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        elf = (ROOT / "build/cxx-runtime-probe.elf").read_bytes()
        if (elf[:7] != b"\x7fELF\x01\x01\x01" or struct.unpack_from("<HH", elf, 16) != (2, 243)
                or struct.unpack_from("<I", elf, 36)[0] & 6):
            raise RuntimeError("GNU C++ probe is not static RV32 ELF/soft-float")
        phoff = struct.unpack_from("<I", elf, 28)[0]
        phsize, phcount = struct.unpack_from("<HH", elf, 42)
        if phsize != 32 or phoff + phsize * phcount > len(elf):
            raise RuntimeError("invalid GNU C++ ELF program headers")
        segments = [struct.unpack_from("<I", elf, phoff + i * phsize)[0] for i in range(phcount)]
        if 3 in segments:
            raise RuntimeError("GNU C++ probe must be static without an interpreter")
        if 7 not in segments:
            symbols = subprocess.check_output(["riscv64-unknown-elf-nm", "--defined-only",
                                               str(ROOT / "build/cxx-runtime-probe.elf")], text=True)
            if "__emutls_get_address" not in symbols:
                raise RuntimeError("C++ probe has neither native TLS nor the GNU emulated-TLS runtime")
        tls_model = "native ELF TLS" if 7 in segments else "GNU emulated TLS, single-thread model"
        compiler = "riscv64-unknown-elf-g++"
        version = subprocess.check_output([compiler, "-dumpfullversion"], text=True).strip()
        if version != "15.1.0":
            raise RuntimeError(f"GNU C++ source/compiler mismatch: {version}")
        for name, filename in (("gnuCrtBegin", "crtbegin.o"), ("gnuCrtEnd", "crtend.o"),
                               ("gnuLibgccUnwind", "libgcc.a")):
            path = Path(subprocess.check_output([compiler, "-march=rv32imac_zicsr_zifencei", "-mabi=ilp32",
                         f"-print-file-name={filename}"], text=True).strip())
            artifacts[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        config = (ROOT / "build/cxx-rv32-sysroot/usr/include/c++/15.1.0/riscv32-unknown-linux-musl/bits/c++config.h").read_text()
        if re.search(r"^#define\s+_GLIBCXX_HAS_GTHREADS", config, re.MULTILINE):
            raise RuntimeError("unexpected GNU native-thread configuration; rerun native thread gates first")
    if args.native_ipc:
        for name, filename in (("nativeIpcProbe", "native-ipc-probe.elf"),
                               ("nativeIpcLibrary", "libcaribe-syllable-native.a")):
            artifacts[name] = hashlib.sha256((ROOT / "build" / filename).read_bytes()).hexdigest()
        kernel = WORKSPACE / "xnu-2050.48.11/osfmk/riscv32/native_ipc.h"
        user = ROOT / "include/uapi/caribe_ipc.h"
        def ipc_declarations(path):
            return path.read_text().split("#ifndef CARIBE_NATIVE_IPC_H", 1)[1].split("#ifdef KERNEL", 1)[0].strip().removesuffix("#endif").strip()
        if ipc_declarations(kernel) != ipc_declarations(user):
            raise RuntimeError("native IPC kernel/userspace ABI mismatch")
    if args.native_areas:
        artifacts["nativeAreaProbe"] = hashlib.sha256((ROOT / "build/native-area-probe.elf").read_bytes()).hexdigest()
        kernel = WORKSPACE / "xnu-2050.48.11/osfmk/riscv32/native_area.h"
        user = ROOT / "include/uapi/caribe_area.h"
        def area_declarations(path):
            return path.read_text().split("#ifndef CARIBE_NATIVE_AREA_H", 1)[1].split("#ifdef KERNEL", 1)[0].strip().removesuffix("#endif").strip()
        if area_declarations(kernel) != area_declarations(user):
            raise RuntimeError("native shared-area kernel/userspace ABI mismatch")
    qmp_port, uart_port = free_port(), free_port()
    cmd = ["qemu-system-riscv32", "-M", "virt", "-m", "256", "-smp", str(args.smp),
           "-bios", args.bios, "-kernel", str(ROOT / "build/caribe_rv32.elf"),
           "-drive", f"if=none,file={ROOT / 'hfsplus.img'},format=raw,id=vd0",
           "-device", "virtio-blk-device,drive=vd0",
           "-device", "virtio-gpu-device", "-device", "virtio-keyboard-device",
           "-device", "virtio-tablet-device",
           "-display", "sdl" if args.visible or args.live else "none",
           "-monitor", "none", "-qmp", f"tcp:127.0.0.1:{qmp_port},server=on,wait=off",
           "-serial", f"tcp:127.0.0.1:{uart_port},server=on,wait=off",
           "-snapshot", "-no-reboot", "-S",
           "-append", ("smp-start smp-gate-f " if args.smp == 2 else "") + "process-gate-11"]
    if args.cpu:
        cmd += ["-cpu", args.cpu]
    serial = bytearray()
    captures = []
    uart = qmp = None
    with (out / "qemu.txt").open("wb") as error, (out / "serial.txt").open("wb") as log:
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=error, stderr=error,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        def pump():
            if uart is not None:
                try:
                    data = uart.recv(65536)
                    if data:
                        serial.extend(data); log.write(data); log.flush()
                except (BlockingIOError, socket.timeout):
                    pass
            text = serial.decode(errors="replace")
            if guest_failure(text):
                raise RuntimeError(f"guest regression: {out / 'serial.txt'}")
            if proc.poll() is not None:
                raise RuntimeError(f"QEMU exited: {out / 'qemu.txt'}")
            return text
        def wait(marker, timeout=90, after=0):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                if marker in pump()[after:]:
                    return
                time.sleep(0.02)
            raise RuntimeError(f"timeout waiting for {marker}: {out / 'serial.txt'}")
        def settle():
            until = time.monotonic() + 1.0
            while time.monotonic() < until:
                pump(); time.sleep(0.01)
        def capture(label):
            settle()
            ppm = out / f"{label}.ppm"
            qmp.call("screendump", filename=str(ppm))
            img = Image.open(ppm).convert("RGB")
            if img.size != (800, 600) or len(img.getcolors(480000) or []) < 10:
                raise RuntimeError(f"blank/incorrect scanout: {ppm}")
            img.save(out / f"{label}.png")
            captures.append(out / f"{label}.png")
            return img
        def input_events(*events):
            qmp.call("input-send-event", events=list(events))
            settle()
        def axis(axis_name, pixel, maximum):
            return {"type": "abs", "data": {"axis": axis_name, "value": pixel * 32767 // maximum}}
        def button(down):
            return {"type": "btn", "data": {"down": down, "button": "left"}}
        def key(code):
            input_events({"type": "key", "data": {"down": True, "key": {"type": "qcode", "data": code}}},
                         {"type": "key", "data": {"down": False, "key": {"type": "qcode", "data": code}}})
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                try:
                    uart = socket.create_connection(("127.0.0.1", uart_port), timeout=1)
                    break
                except OSError:
                    if proc.poll() is not None:
                        raise RuntimeError((out / "qemu.txt").read_text())
                    time.sleep(0.1)
            if uart is None:
                raise RuntimeError("UART did not open")
            uart.setblocking(False)
            qmp = Qmp(qmp_port)
            qmp.call("cont")
            wait("bash-5.3$ ")
            if args.native_cxx:
                start = len(serial)
                uart.sendall(b"/bin/cxx-runtime-probe; echo NATIVE_CXX_STATUS=$?\n")
                wait("[native-cxx-gate-D] CRT global constructor destructor fork-exec reinitialization PASS", timeout=120, after=start)
                wait("\nNATIVE_CXX_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                cxx_text = pump()[start:]
                for gate in "ABCD":
                    lines = [line for line in cxx_text.splitlines() if f"[native-cxx-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing GNU C++ gate {gate}")
                    (out / f"gate-native-cxx-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "exceptions=10000 destructors=10000" not in cxx_text:
                    raise RuntimeError("GNU exception/unwind stress evidence missing")
            if args.syllable_string:
                start = len(serial)
                uart.sendall(b"/bin/syllable-string-probe; echo SYLLABLE_STRING_STATUS=$?\n")
                wait("[syllable-string] genuine Syllable String gates A-D PASS; native XNU, no Wayland/X11",
                     timeout=240, after=start)
                wait("\nSYLLABLE_STRING_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                string_text = pump()[start:]
                for gate in "ABCD":
                    lines = [line for line in string_text.splitlines() if f"[syllable-string-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing genuine Syllable String gate {gate}")
                    (out / f"gate-syllable-string-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "independent exec String/native-port rounds=10000 large-messages=10" not in string_text:
                    raise RuntimeError("Syllable String/native IPC stress evidence missing")
            if args.syllable_message:
                start = len(serial)
                uart.sendall(b"/bin/syllable-message-probe; echo SYLLABLE_MESSAGE_STATUS=$?\n")
                wait("[syllable-message] genuine Message data-core gates A-D PASS; no Looper stubs, no Wayland/X11",
                     timeout=240, after=start)
                wait("\nSYLLABLE_MESSAGE_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                message_text = pump()[start:]
                for gate in "ABCD":
                    lines = [line for line in message_text.splitlines() if f"[syllable-message-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing genuine Message data-core gate {gate}")
                    (out / f"gate-syllable-message-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "malformed=10000 all-truncations guard-page" not in message_text or "real Post/Read rounds=10000" not in message_text:
                    raise RuntimeError("Message malformed/transport stress evidence missing")
            if args.native_sync:
                start = len(serial)
                uart.sendall(f"/bin/native-sync-probe --gate {args.sync_gate}; echo NATIVE_SYNC_STATUS=$?\n".encode())
                wait(f"[native-sync] gates A-{args.sync_gate} PASS; native XNU counting semaphores, no user-thread claims",
                     timeout=240, after=start)
                wait("\nNATIVE_SYNC_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                sync_text = pump()[start:]
                for gate in "ABCDE"[:ord(args.sync_gate) - ord("A") + 1]:
                    lines = [line for line in sync_text.splitlines() if f"[native-sync-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing native semaphore gate {gate}")
                    (out / f"gate-native-sync-{gate}.txt").write_text("\n".join(lines) + "\n")
                if args.sync_gate >= "D" and "rounds=10000 acquisitions=20000 releases=20000 scheduler-waits=" not in sync_text:
                    raise RuntimeError("native semaphore stress evidence missing")
                if args.sync_gate == "E" and ("deletion/reuse EIDRM=16; owner exit/exec wakes=16;" not in sync_text
                        or "sleep EINTR/remainder=3 PASS" not in sync_text):
                    raise RuntimeError("native semaphore/clock lifecycle evidence missing")
            if args.native_ipc:
                start = len(serial)
                uart.sendall(b"/bin/native-ipc-probe; echo NATIVE_IPC_STATUS=$?\n")
                wait("[native-ipc] gates A-D PASS; native XNU ports, no Wayland/X11", timeout=240, after=start)
                wait("\nNATIVE_IPC_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                native_text = pump()[start:]
                for gate in "ABCD":
                    lines = [line for line in native_text.splitlines() if f"[native-ipc-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing native IPC gate {gate}")
                    (out / f"gate-native-ipc-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "independent exec ping-pong=10000 max-payload=8192 scheduler-waits=" not in native_text:
                    raise RuntimeError("native IPC stress evidence missing")
            if args.native_areas:
                start = len(serial)
                uart.sendall(b"/bin/native-area-probe; echo NATIVE_AREA_STATUS=$?\n")
                wait("[native-area] gates A-E PASS; real shared Sv32 pages, no Wayland/X11", timeout=240, after=start)
                wait("\nNATIVE_AREA_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                area_text = pump()[start:]
                for gate in "ABCDE":
                    lines = [line for line in area_text.splitlines() if f"[native-area-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing native shared-area gate {gate}")
                    (out / f"gate-native-area-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "independent-exec shared-memory rounds=10000" not in area_text:
                    raise RuntimeError("shared-area stress evidence missing")
                shared = capture("00-shared-area")
                for x, y in ((0, 0), (127, 81), (255, 255), (480, 310), (799, 599)):
                    if shared.getpixel((x, y)) != (x & 255, y & 255, (x ^ y) & 255):
                        raise RuntimeError(f"shared framebuffer wrong pixel at {x},{y}")
            isa_match = re.search(r"\[boot-report\] cpu hart=\d+ harts=\d+ isa=(rv32[a-z]+)(?:_| )", pump())
            if args.freetype:
                start = len(serial)
                uart.sendall(f"/bin/freetype-probe --gate {args.font_gate}; echo FREETYPE_STATUS=$?\n".encode())
                wait(f"[freetype] gates A-{args.font_gate} PASS; authentic font engine, not Syllable AppServer; no Wayland/X11",
                     timeout=180, after=start)
                wait("\nFREETYPE_STATUS=0\r", after=start)
                wait("bash-5.3$ ", after=start)
                font_text = pump()[start:]
                for gate in "ABCD"[:ord(args.font_gate) - ord("A") + 1]:
                    lines = [line for line in font_text.splitlines() if f"[freetype-gate-{gate}]" in line]
                    if not lines or not all("PASS" in line for line in lines):
                        raise RuntimeError(f"missing genuine FreeType gate {gate}")
                    (out / f"gate-freetype-{gate}.txt").write_text("\n".join(lines) + "\n")
                if "engine=2.15.0 TrueType" not in font_text:
                    raise RuntimeError("FreeType engine version/type mismatch")
                if args.font_gate >= "B" and "raster-rounds=10000" not in font_text:
                    raise RuntimeError("FreeType raster stress evidence missing")
                if args.font_gate >= "C" and "truncations=256 guard-page invalid-signatures=1024 allocation-fault-cases=32 zero-leak" not in font_text:
                    raise RuntimeError("FreeType bounds/allocator evidence missing")
                if args.font_gate == "D":
                    fonts = capture("00-freetype-fonts")
                    match = re.search(r"frame-fnv32=([0-9a-f]{8}) GPU-present zero-area-leak PASS", font_text)
                    if not match or scanout_fnv(fonts) != int(match.group(1), 16):
                        raise RuntimeError("GPU font scanout differs from shared Sv32 frame")
            base_isa = isa_match.group(1) if isa_match else None
            if args.cpu == IMACSU_CPU and base_isa != "rv32imac":
                raise RuntimeError(f"no-F/D/H test reported unexpected base ISA: {base_isa}")
            start = len(serial)
            uart.sendall(b"/bin/private-vm-probe\n")
            wait("private heap/mmap fork-exec isolation=32 recycling=256 PASS", after=start)
            wait("bash-5.3$ ", after=start)
            start = len(serial)
            uart.sendall(b"/bin/caribe-session --list\n")
            wait("blocked: Wayland compositor")
            wait("bash-5.3$ ", after=start)
            for selection, status in (("wayland", 3), ("x11", 3), ("unknown", 2)):
                start = len(serial)
                uart.sendall(f"/bin/caribe-session {selection}; echo SESSION_SELECTION_STATUS=$?\n".encode())
                wait(f"\nSESSION_SELECTION_STATUS={status}\r", after=start)
                wait("bash-5.3$ ", after=start)
            uart.sendall(b"/bin/caribe-session\n")
            wait("[graphics-gate-C] userspace frame presented PASS")
            initial = capture("01-syllable")
            for marker in ("[graphics-gate-A]", "[graphics-gate-B]", "[graphics-gate-C]"):
                if marker not in pump():
                    raise RuntimeError(f"missing {marker}")
            if args.live:
                print("Real XNU/Syllable component session is running in QEMU. Close the QEMU window to stop.", flush=True)
                live_deadline = time.monotonic() + args.live_seconds if args.live_seconds else None
                while proc.poll() is None:
                    if live_deadline is not None and time.monotonic() >= live_deadline:
                        qmp.call("quit")
                        proc.wait(timeout=5)
                        break
                    try:
                        data = uart.recv(65536)
                        if data:
                            serial.extend(data); log.write(data); log.flush()
                    except (BlockingIOError, socket.timeout):
                        pass
                    text = serial.decode(errors="replace").lower()
                    if (any(marker in text for marker in ("panic", "unexpected trap", "fatal user signal"))
                            or re.search(r"\[smp-gate-[a-f]\][^\r\n]* fail", text)):
                        raise RuntimeError(f"live session kernel regression: {out / 'serial.txt'}")
                    time.sleep(0.02)
                if proc.returncode != 0:
                    raise RuntimeError(f"QEMU exited with status {proc.returncode}")
                result_path.write_text(json.dumps({"result": "LIVE_CLOSED", "smp": args.smp,
                    "bios": args.bios, "cpu": args.cpu or "QEMU default", "baseIsa": base_isa,
                    "automatedInputGates": False,
                    "artifactSha256": artifacts,
                    "screenshots": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in captures}}, indent=2) + "\n")
                return
            key("tab")
            wait("keyboard code=15 count=1 PASS")
            focused = capture("02-keyboard-focus")
            if ImageChops.difference(initial, focused).getbbox() is None:
                raise RuntimeError("keyboard did not change visible window focus")
            if initial.getpixel((600, 352)) != (120, 120, 120) or focused.getpixel((600, 352)) != (102, 136, 187):
                raise RuntimeError("Syllable focus did not change the actual title-bar pixels")
            input_events(axis("x", 190, 799), axis("y", 112, 599))
            input_events(button(True))
            wait("mouse button focus=0 hit=6")
            input_events(axis("x", 310, 799), axis("y", 205, 599))
            input_events(button(False))
            dragged = capture("03-mouse-drag")
            if ImageChops.difference(focused, dragged).getbbox() is None:
                raise RuntimeError("mouse did not move visible window")
            if dragged.getpixel((72, 102)) != (60, 69, 75) or dragged.getpixel((192, 195)) != (255, 255, 255):
                raise RuntimeError("window drag did not move the original Syllable border")
            # Repeated real keyboard events, verifying guest count rather than host submissions.
            for _ in range(10):
                key("tab")
            wait("keyboard code=15 count=11 PASS")
            final = capture("04-input-verified")
            start = len(serial)
            key("esc")
            wait("[graphics-gate-E] clean exit", after=start)
            wait("bash-5.3$ ", after=start)
            start = len(serial)
            uart.sendall(b"/bin/caribe-session\n")
            wait("[graphics-gate-C] userspace frame presented PASS", after=start)
            restarted = capture("05-session-restart")
            if restarted.getpixel((72, 102)) != (255, 255, 255) or restarted.getpixel((600, 352)) != (120, 120, 120):
                raise RuntimeError("restarted session did not reset its window state")
            start = len(serial)
            key("esc")
            wait("[graphics-gate-E] clean exit", after=start)
            wait("bash-5.3$ ", after=start)
            uart.sendall(b"printf 'GRAPHICS_RETURN_TO_BASH_PASS\\n'\nexit\n")
            wait("GRAPHICS_RETURN_TO_BASH_PASS")
            wait("[process-gate-11] Gate 11 persistent interactive Bash PASS")
            text = pump()
            for marker in ("dropped=0 PASS", "[linux] exit status=0", "[boot-report] CaribeSecurity ORANGE"):
                wait(marker)
            if args.smp == 2:
                wait("[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")
            if args.bios != "default":
                wait("privileged signing DENIED PASS")
            text = pump()
            if "GRAPHICS_RETURN_TO_BASH_PASS" not in text.splitlines():
                raise RuntimeError("Bash did not execute the post-graphics command")
            for gate in "ABCDE":
                lines = [line for line in text.splitlines() if f"[graphics-gate-{gate}]" in line]
                (out / f"gate-{gate}.txt").write_text("\n".join(lines) + "\n")
            (out / "gate-private-vm.txt").write_text("\n".join(
                line for line in text.splitlines() if "[graphics-vm]" in line) + "\n")
            result = {"result": "PASS", "platform": "QEMU virt RV32", "smp": args.smp,
                      "cpu": args.cpu or "QEMU default",
                      "baseIsa": base_isa,
                      "bios": args.bios, "gates": ["A-video", "B-negative-ABI", "C-userspace-Syllable-component",
                      "D-keyboard-mouse-drag", "E-event-integrity-exit-Bash"],
                      "resolution": [800, 600],
                      "sessionRestarts": 1,
                      "blockedSessionStatuses": {"wayland": 3, "x11": 3, "unknown": 2},
                      "privateVm": {"forkExecIsolationCycles": 32, "zeroingRecycleCycles": 256},
                      "nativeIpc": {"gates": ["A", "B", "C", "D"], "pingPongRounds": 10000,
                                    "maxPayload": 8192} if args.native_ipc else None,
                      "nativeSync": {"gates": list("ABCDE"[:ord(args.sync_gate) - ord("A") + 1]),
                                     "objects": 64, "recycleCycles": 256 if args.sync_gate >= "B" else 0,
                                     "sharedMemoryRounds": 10000 if args.sync_gate >= "D" else 0,
                                     "profile": "native counting semaphores, creator-owned lifecycle",
                                     "userThreadsImplemented": False} if args.native_sync else None,
                      "freetype": {"gates": list("ABCD"[:ord(args.font_gate) - ord("A") + 1]),
                                   "engine": "2.15.0", "fonts": "Bitstream Vera 1.10",
                                   "rasterRounds": 10000 if args.font_gate >= "B" else 0,
                                   "truncations": 256 if args.font_gate >= "C" else 0,
                                   "invalidSignatures": 1024 if args.font_gate >= "C" else 0,
                                   "allocationFailureCases": 32 if args.font_gate >= "C" else 0,
                                   "scanoutFnv32": match.group(1) if args.font_gate == "D" else None,
                                   "appServerBuilt": False} if args.freetype else None,
                      "nativeAreas": {"gates": ["A", "B", "C", "D", "E"], "sharedMemoryRounds": 10000,
                                      "objects": 32, "views": 64, "poolPages": 1024,
                                      "recycleCycles": 256, "sharedFramebuffer": [800, 600],
                                      "verifiedPixels": 5} if args.native_areas else None,
                      "nativeCxx": {"gates": ["A", "B", "C", "D"], "exceptions": 10000,
                                    "unwindDestructors": 10000, "forkExecCycles": 16,
                                    "libc": "musl 1.2.5", "libstdcxx": "GNU 15.1.0",
                                    "tlsModel": tls_model, "softFloatAbi": True,
                                    "threadModel": "single"} if args.native_cxx else None,
                      "kernelSha256": artifacts["xnu"],
                      "syllableMessage": {"gates": ["A", "B", "C", "D"], "malformedInputs": 10000,
                                          "transportRounds": 10000, "forkExecCycles": 16,
                                          "maxWireBytes": 8192, "nestedDepthLimit": 16,
                                          "profile": "genuine data core, Looper/Variant delivery excluded",
                                          "legacyUnflatten": "trusted complete buffers only",
                                          "appServerBuilt": False} if args.syllable_message else None,
                      "syllableString": {"gates": ["A", "B", "C", "D"], "trimRounds": 10000,
                                         "ipcRounds": 10000, "forkExecCycles": 16,
                                         "component": "genuine libsyllable os::String",
                                         "appServerBuilt": False} if args.syllable_string else None,
                      "artifactSha256": artifacts,
                      "screenshots": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in captures}}
            result_path.write_text(json.dumps(result, indent=2) + "\n")
            print(f"PASS graphics gates A-E: {out}", flush=True)
        except Exception as failure:
            result_path.write_text(json.dumps({"result": "FAIL", "smp": args.smp,
                                  "bios": args.bios, "error": str(failure)}, indent=2) + "\n")
            raise
        finally:
            if qmp is not None:
                qmp.close()
            if uart is not None:
                uart.close()
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill(); proc.wait(timeout=5)

def run():
    try:
        main()
    except Exception as failure:
        if RUN_RESULT_PATH is not None:
            record = json.loads(RUN_RESULT_PATH.read_text())
            record.update(result="FAIL", error=str(failure))
            RUN_RESULT_PATH.write_text(json.dumps(record, indent=2) + "\n")
        raise

if __name__ == "__main__":
    run()
