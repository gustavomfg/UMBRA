#!/usr/bin/env python3
"""Control a disposable Nocturne 0.8 QEMU/KVM guest without host privileges.

The VM lives outside the repository (default ~/.local/share/nocturne-greeter-vm).
Management uses QMP (screen, keyboard, snapshots, NIC link) and the QEMU guest
agent over virtio-serial (commands inside the guest). There is no inbound port
forwarding, host folder mount or host credential in the guest.

Secrets: `set-password` and `type-secret` read a password from a 0600 file in
the VM directory that this tool generates; the value is never printed, put on
a command line or written to a log.
"""

import argparse
import base64
import json
import os
import secrets
import socket
import string
import subprocess
import sys
import time
from pathlib import Path

VM_DIR = Path(os.environ.get("NOCTURNE_VM_DIR", Path.home() / ".local/share/nocturne-greeter-vm"))
QMP_SOCK = VM_DIR / "qmp.sock"
QGA_SOCK = VM_DIR / "qga.sock"
SECRET_FILE = VM_DIR / "test-user.secret"


class Qmp:
    def __init__(self, path=QMP_SOCK):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(str(path))
        self.file = self.sock.makefile("rwb")
        self._read()  # greeting
        self.call("qmp_capabilities")

    def _read(self):
        while True:
            line = self.file.readline()
            if not line:
                raise ConnectionError("QMP closed")
            message = json.loads(line)
            if "event" in message:
                continue
            return message

    def call(self, command, **arguments):
        payload = {"execute": command}
        if arguments:
            payload["arguments"] = arguments
        self.file.write(json.dumps(payload).encode() + b"\n")
        self.file.flush()
        reply = self._read()
        if "error" in reply:
            raise RuntimeError(f"{command}: {reply['error']}")
        return reply.get("return")

    def hmp(self, command_line):
        return self.call("human-monitor-command", **{"command-line": command_line})


class Qga:
    def __init__(self, path=QGA_SOCK, timeout=10):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        self.sock.connect(str(path))
        self.file = self.sock.makefile("rwb")
        # Resynchronise: discard anything left over from a previous client.
        token = secrets.randbelow(2**31)
        self.file.write(b"\xff" + json.dumps({"execute": "guest-sync-delimited", "arguments": {"id": token}}).encode() + b"\n")
        self.file.flush()
        while True:
            line = self.file.readline()
            if not line:
                raise ConnectionError("QGA closed")
            line = line.lstrip(b"\xff").strip()
            if not line:
                continue
            try:
                if json.loads(line).get("return") == token:
                    break
            except json.JSONDecodeError:
                continue

    def call(self, command, **arguments):
        payload = {"execute": command}
        if arguments:
            payload["arguments"] = arguments
        self.file.write(json.dumps(payload).encode() + b"\n")
        self.file.flush()
        reply = json.loads(self.file.readline())
        if "error" in reply:
            raise RuntimeError(f"{command}: {reply['error']}")
        return reply.get("return")

    def run(self, argv, stdin=None, timeout=600, env=None):
        arguments = {"path": argv[0], "arg": argv[1:], "capture-output": True}
        if stdin is not None:
            arguments["input-data"] = base64.b64encode(stdin).decode()
        if env:
            arguments["env"] = env
        pid = self.call("guest-exec", **arguments)["pid"]
        deadline = time.monotonic() + timeout
        while True:
            status = self.call("guest-exec-status", pid=pid)
            if status.get("exited"):
                out = base64.b64decode(status.get("out-data", "")).decode(errors="replace")
                err = base64.b64decode(status.get("err-data", "")).decode(errors="replace")
                return status.get("exitcode", -1), out, err
            if time.monotonic() > deadline:
                raise TimeoutError(f"guest command timed out: {argv[0]}")
            time.sleep(0.25)


# --- keyboard -----------------------------------------------------------------

SHIFTED = {
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8",
    "(": "9", ")": "0", "_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right",
    "|": "backslash", ":": "semicolon", '"': "apostrophe", "<": "comma", ">": "dot",
    "?": "slash", "~": "grave_accent",
}
PLAIN = {
    "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right", "\\": "backslash",
    ";": "semicolon", "'": "apostrophe", ",": "comma", ".": "dot", "/": "slash", "`": "grave_accent",
    " ": "spc", "\n": "ret",
}


def char_to_keys(char):
    if char.isdigit() or ("a" <= char <= "z"):
        return [char]
    if "A" <= char <= "Z":
        return ["shift", char.lower()]
    if char in PLAIN:
        return [PLAIN[char]]
    if char in SHIFTED:
        return ["shift", SHIFTED[char]]
    raise ValueError("unsupported character")


def key_event(qcode, down):
    return {"type": "key", "data": {"down": down, "key": {"type": "qcode", "data": qcode}}}


def press_combo(qmp, keys, hold=0.03):
    qmp.call("input-send-event", events=[key_event(k, True) for k in keys])
    time.sleep(hold)
    qmp.call("input-send-event", events=[key_event(k, False) for k in reversed(keys)])
    time.sleep(0.03)


def type_text(qmp, text):
    for char in text:
        press_combo(qmp, char_to_keys(char))


def click(qmp, x, y, width=1280, height=720):
    ax = int(x * 32767 / (width - 1))
    ay = int(y * 32767 / (height - 1))
    qmp.call("input-send-event", events=[
        {"type": "abs", "data": {"axis": "x", "value": ax}},
        {"type": "abs", "data": {"axis": "y", "value": ay}},
    ])
    time.sleep(0.05)
    qmp.call("input-send-event", events=[{"type": "btn", "data": {"down": True, "button": "left"}}])
    time.sleep(0.05)
    qmp.call("input-send-event", events=[{"type": "btn", "data": {"down": False, "button": "left"}}])


# --- commands -----------------------------------------------------------------

def cmd_start(args):
    disk = VM_DIR / "disk.qcow2"
    if not disk.exists():
        sys.exit(f"missing {disk}")
    pidfile = VM_DIR / "qemu.pid"
    if pidfile.exists():
        try:
            pid = int(pidfile.read_text().strip())
            os.kill(pid, 0)
        except (ValueError, ProcessLookupError):
            pass
        except PermissionError:
            sys.exit(f"a VM process (pid {pid}) is already running; stop it first")
        else:
            sys.exit(f"a VM process (pid {pid}) is already running; stop it first")
    # Only remove stale sockets once no VM can still be listening on them.
    for sock in (QMP_SOCK, QGA_SOCK):
        if sock.exists():
            sock.unlink()
    argv = [
        "qemu-system-x86_64",
        "-name", "nocturne-greeter-0.8",
        "-machine", "q35,accel=kvm",
        "-cpu", "host",
        "-smp", str(args.cpus),
        "-m", f"{args.memory}M",
        "-drive", f"file={disk},if=virtio,format=qcow2,discard=unmap",
        "-vga", "none",
        "-device", "bochs-display,xres=1280,yres=720",
        "-display", "none",
        "-device", "qemu-xhci",
        "-device", "usb-tablet",
        "-netdev", "user,id=net0",
        "-device", "virtio-net-pci,netdev=net0,id=nic0",
        "-chardev", f"socket,path={QGA_SOCK},server=on,wait=off,id=qga0",
        "-device", "virtio-serial",
        "-device", "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0",
        "-serial", f"file:{VM_DIR / 'serial.log'}",
        "-qmp", f"unix:{QMP_SOCK},server=on,wait=off",
        "-pidfile", str(VM_DIR / "qemu.pid"),
        "-daemonize",
    ]
    if args.seed_url:
        argv += ["-smbios", f"type=1,serial=ds=nocloud;s={args.seed_url}"]
    if args.snapshot:
        argv += ["-snapshot"]
    if args.loadvm:
        argv += ["-loadvm", args.loadvm]
    if args.paused:
        argv += ["-S"]
    if args.vnc:
        # Local-only VNC (display :1 = TCP 5901) so a person can watch and type.
        argv += ["-vnc", "127.0.0.1:1"]
    subprocess.run(argv, check=True)
    print("started")


def cmd_stop(args):
    if args.force:
        Qmp().call("quit")
        print("VM process stopped")
        return
    # Prefer an orderly guest shutdown; the ACPI button can be ignored.
    try:
        qga = Qga(timeout=5)
        payload = {"execute": "guest-shutdown", "arguments": {"mode": "powerdown"}}
        qga.file.write(json.dumps(payload).encode() + b"\n")
        qga.file.flush()
        print("guest shutdown requested")
        return
    except (OSError, ConnectionError, TimeoutError, json.JSONDecodeError):
        pass
    Qmp().call("system_powerdown")
    print("ACPI power button pressed")


def cmd_qmp(args):
    qmp = Qmp()
    arguments = json.loads(args.arguments) if args.arguments else {}
    print(json.dumps(qmp.call(args.command, **arguments), indent=2))


def cmd_hmp(args):
    print(Qmp().hmp(" ".join(args.line)))


def cmd_wait_agent(args):
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        try:
            Qga(timeout=3).call("guest-ping")
            print("guest agent ready")
            return
        except (OSError, ConnectionError, TimeoutError, json.JSONDecodeError):
            time.sleep(2)
    sys.exit("guest agent not ready")


def cmd_exec(args):
    stdin = sys.stdin.buffer.read() if args.stdin else None
    code, out, err = Qga().run(args.argv, stdin=stdin, timeout=args.timeout)
    sys.stdout.write(out)
    sys.stderr.write(err)
    sys.exit(code)


def cmd_sh(args):
    script = sys.stdin.read() if args.script == "-" else args.script
    code, out, err = Qga().run(["/bin/bash", "-s"], stdin=script.encode(), timeout=args.timeout)
    sys.stdout.write(out)
    sys.stderr.write(err)
    sys.exit(code)


def cmd_push(args):
    data = Path(args.source).read_bytes()
    qga = Qga()
    handle = qga.call("guest-file-open", path=args.dest, mode="w")
    for offset in range(0, len(data), 48 * 1024):
        qga.call("guest-file-write", handle=handle, **{"buf-b64": base64.b64encode(data[offset:offset + 48 * 1024]).decode()})
    qga.call("guest-file-close", handle=handle)
    print(f"pushed {len(data)} bytes")


def cmd_pull(args):
    qga = Qga()
    handle = qga.call("guest-file-open", path=args.source, mode="r")
    chunks = []
    while True:
        result = qga.call("guest-file-read", handle=handle, count=48 * 1024)
        chunks.append(base64.b64decode(result["buf-b64"]))
        if result.get("eof"):
            break
    qga.call("guest-file-close", handle=handle)
    Path(args.dest).write_bytes(b"".join(chunks))
    print(f"pulled {sum(map(len, chunks))} bytes")


def cmd_shot(args):
    Qmp().call("screendump", filename=str(Path(args.path).resolve()), format="png")
    print(args.path)


def cmd_type(args):
    type_text(Qmp(), args.text)


def cmd_key(args):
    qmp = Qmp()
    for combo in args.combos:
        press_combo(qmp, combo.split("-"))
        time.sleep(args.delay)


def cmd_click(args):
    click(Qmp(), args.x, args.y)


def cmd_new_secret(args):
    # Letters, digits and keyboard-safe symbols that the US layout types reliably.
    alphabet = string.ascii_letters + string.digits + "-_.,;!@#%+="
    value = "".join(secrets.choice(alphabet) for _ in range(20))
    fd = os.open(SECRET_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(value)
    print(f"generated a new test-user secret in {SECRET_FILE} (value not shown)")


def read_secret():
    return SECRET_FILE.read_text().strip()


def cmd_set_password(args):
    payload = f"{args.user}:{read_secret()}\n".encode()
    code, out, err = Qga().run(["/usr/bin/chpasswd"], stdin=payload)
    del payload
    if code != 0:
        sys.exit(f"chpasswd failed: {err.strip()}")
    print(f"password set for {args.user} (value not shown)")


def cmd_type_secret(args):
    qmp = Qmp()
    secret = read_secret()
    if args.wrong:
        # A different value of the same shape, never the real one.
        secret = secret[::-1] + "x"
    type_text(qmp, secret)
    del secret
    if args.enter:
        press_combo(qmp, ["ret"])


def cmd_scan_secret(args):
    """Count occurrences of the test secret in guest logs and greeter state.

    The secret is passed on stdin to grep -F -f, never as an argument."""
    # Keep the pattern on a separate stdin stream. Redirecting grep's stdin
    # inside a journalctl pipeline discards the journal and can falsely pass.
    script = """
import pathlib, subprocess, sys
secret = sys.stdin.buffer.read().rstrip(b"\\n")
if not secret:
    raise SystemExit("empty canary")
journal = subprocess.run(["journalctl", "-b", "-o", "cat", "--no-pager"], capture_output=True)
if journal.returncode:
    raise SystemExit("journal query failed")
journal_hits = sum(secret in line for line in journal.stdout.splitlines())
roots = [p for p in ["/var/log", "/tmp", "/run/user", "/var/cache", "/var/lib/greetd", "/home"] if pathlib.Path(p).exists()]
files = subprocess.run(["grep", "-rIlF", "-f", "/dev/stdin", "--", *roots], input=secret+b"\\n", capture_output=True)
if files.returncode not in (0, 1):
    raise SystemExit("file scan failed")
file_hits = len(files.stdout.splitlines())
print("journal:", journal_hits)
print("files:", file_hits)
raise SystemExit(bool(journal_hits or file_hits))
"""
    code, out, err = Qga().run(["/usr/bin/python3", "-I", "-c", script], stdin=(read_secret() + "\n").encode())
    sys.stdout.write(out)
    sys.stderr.write(err)
    print("canary absent" if code == 0 else "CANARY FOUND OR SCAN FAILED")
    sys.exit(code)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("start")
    p.add_argument("--cpus", type=int, default=4)
    p.add_argument("--memory", type=int, default=6144)
    p.add_argument("--snapshot", action="store_true", help="write all guest changes to a temporary overlay; discard on exit")
    p.add_argument("--seed-url")
    p.add_argument("--loadvm")
    p.add_argument("--paused", action="store_true")
    p.add_argument("--vnc", action="store_true", help="expose the screen on 127.0.0.1:5901")
    p.set_defaults(func=cmd_start)

    p = sub.add_parser("stop")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_stop)

    p = sub.add_parser("qmp")
    p.add_argument("command")
    p.add_argument("arguments", nargs="?")
    p.set_defaults(func=cmd_qmp)

    p = sub.add_parser("hmp")
    p.add_argument("line", nargs="+")
    p.set_defaults(func=cmd_hmp)

    p = sub.add_parser("wait-agent")
    p.add_argument("--timeout", type=int, default=600)
    p.set_defaults(func=cmd_wait_agent)

    p = sub.add_parser("exec")
    p.add_argument("--stdin", action="store_true")
    p.add_argument("--timeout", type=int, default=600)
    p.add_argument("argv", nargs="+")
    p.set_defaults(func=cmd_exec)

    p = sub.add_parser("sh", help="run a bash script (argument or - for stdin) as root in the guest")
    p.add_argument("--timeout", type=int, default=1800)
    p.add_argument("script")
    p.set_defaults(func=cmd_sh)

    p = sub.add_parser("push")
    p.add_argument("source")
    p.add_argument("dest")
    p.set_defaults(func=cmd_push)

    p = sub.add_parser("pull")
    p.add_argument("source")
    p.add_argument("dest")
    p.set_defaults(func=cmd_pull)

    p = sub.add_parser("shot")
    p.add_argument("path")
    p.set_defaults(func=cmd_shot)

    p = sub.add_parser("type")
    p.add_argument("text")
    p.set_defaults(func=cmd_type)

    p = sub.add_parser("key", help="key combos such as ret, esc, ctrl-alt-f3, backspace")
    p.add_argument("--delay", type=float, default=0.15)
    p.add_argument("combos", nargs="+")
    p.set_defaults(func=cmd_key)

    p = sub.add_parser("click")
    p.add_argument("x", type=int)
    p.add_argument("y", type=int)
    p.set_defaults(func=cmd_click)

    p = sub.add_parser("new-secret")
    p.set_defaults(func=cmd_new_secret)

    p = sub.add_parser("set-password")
    p.add_argument("user")
    p.set_defaults(func=cmd_set_password)

    p = sub.add_parser("type-secret")
    p.add_argument("--wrong", action="store_true")
    p.add_argument("--enter", action="store_true")
    p.set_defaults(func=cmd_type_secret)

    p = sub.add_parser("scan-secret")
    p.set_defaults(func=cmd_scan_secret)

    args = parser.parse_args()
    VM_DIR.mkdir(parents=True, exist_ok=True)
    args.func(args)


if __name__ == "__main__":
    main()
