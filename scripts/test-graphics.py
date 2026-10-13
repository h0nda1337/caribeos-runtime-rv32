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
import time
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent.parent
IMACSU_CPU = "rv32,f=false,d=false,h=false,zfa=false"

def build_hashes():
    files = {
        "xnu": WORKSPACE / "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf",
        "cbx": ROOT / "build/caribe_rv32.elf",
        "initrd": ROOT / "build/initrd.img",
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--smp", type=int, choices=(1, 2), default=1)
    parser.add_argument("--bios", default="default")
    parser.add_argument("--cpu", default="", help="Optional QEMU CPU configuration")
    parser.add_argument("--visible", action="store_true")
    parser.add_argument("--live", action="store_true", help="Open the real QEMU session; close its window to stop")
    parser.add_argument("--live-seconds", type=float, default=0,
                        help="Optional positive live-preview duration; zero waits for window close")
    args = parser.parse_args()
    if args.live_seconds < 0 or (args.live_seconds and not args.live):
        parser.error("--live-seconds requires --live and a nonnegative duration")
    verify_abi()
    artifacts = build_hashes()
    name = ("opensbi" if args.bios == "default" else "securesbi") + f"-smp{args.smp}"
    if args.cpu:
        name += "-imacsu" if args.cpu == IMACSU_CPU else "-custom-cpu"
    if args.live:
        name += "-live"
    out = ROOT / "build/graphics-tests" / name
    out.mkdir(parents=True, exist_ok=True)
    result_path = out / "result.json"
    result_path.write_text(json.dumps({"result": "RUNNING", "smp": args.smp,
                          "bios": args.bios, "live": args.live}, indent=2) + "\n")
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
            if ("panic" in text.lower() or "unexpected trap" in text.lower() or "fatal user signal" in text
                    or re.search(r"\[smp-gate-[a-f]\][^\r\n]* FAIL", text)):
                raise RuntimeError(f"kernel regression: {out / 'serial.txt'}")
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
            isa_match = re.search(r"\[boot-report\] cpu hart=\d+ harts=\d+ isa=(rv32[a-z]+)(?:_| )", pump())
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
                      "kernelSha256": artifacts["xnu"],
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

if __name__ == "__main__":
    main()
