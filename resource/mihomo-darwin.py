"""Supervise unprivileged Mihomo behind PF."""

import os
import json
from pathlib import Path
import pwd
import re
import signal
import socket
import subprocess
import sys
import time

PF = "/sbin/pfctl"
ANCHOR = "com.apple/antares-mihomo"
TOKEN = Path("/var/run/mihomo-pf-token")
FIREWALL = "/usr/libexec/ApplicationFirewall/socketfilterfw"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


def enable_pf(rules):
    if 'anchor "com.apple/*"' not in run(PF, "-sr").stdout:
        raise ValueError("Missing system PF anchor")
    run(PF, "-a", ANCHOR, "-f", rules)
    if TOKEN.exists():
        run(PF, "-X", str(int(TOKEN.read_text())))
        TOKEN.unlink()
    enabled = run(PF, "-E")
    token = re.search(r"Token\s*:\s*(\d+)", enabled.stdout + enabled.stderr)
    if token is None:
        raise ValueError("Missing PF reference token")
    TOKEN.write_text(token[1])


def disable_pf():
    run(PF, "-a", ANCHOR, "-F", "rules")
    if TOKEN.exists():
        run(PF, "-X", str(int(TOKEN.read_text())))
        TOKEN.unlink()


def wait_ports(ports):
    deadline = time.monotonic() + 120
    while True:
        try:
            for address, port, protocol in ports:
                with socket.socket(socket.AF_INET, protocol) as probe:
                    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    probe.bind((address, port))
            return
        except OSError:
            if time.monotonic() >= deadline:
                raise ValueError("Mihomo ports are still occupied") from None
            time.sleep(1)


def start(template, subscription, prepare, core, ctl, rules):
    os.umask(0o077)
    user = pwd.getpwnam("antares")
    state = Path(user.pw_dir) / "Library/Application Support/mihomo"
    child_args = {"user": user.pw_uid, "group": user.pw_gid, "extra_groups": [],
                  "env": os.environ | {"HOME": user.pw_dir, "USER": user.pw_name, "LOGNAME": user.pw_name}}
    deadline = time.monotonic() + 120
    while not Path(subscription).is_file() or Path(subscription).stat().st_uid != user.pw_uid:
        if time.monotonic() >= deadline:
            raise ValueError("Subscription decryption timed out")
        time.sleep(1)
    # Keep subscription errors private.
    run(sys.executable, prepare, template, subscription, **child_args)
    settings = json.loads(Path(template).read_text())
    listeners = [{"listen": "127.0.0.1", "port": settings["mixed-port"], "udp": True}] + settings["listeners"]
    ports = [(entry["listen"], entry["port"], socket.SOCK_STREAM) for entry in listeners]
    ports += [(entry["listen"], entry["port"], socket.SOCK_DGRAM) for entry in listeners if entry.get("udp")]
    ports.append(("0.0.0.0" if rules else "127.0.0.1", 17900, socket.SOCK_STREAM))
    # Darwin loads replacements before unloading removed jobs.
    wait_ports(ports)
    child = None
    firewall_added = False
    try:
        if rules:
            enable_pf(rules)
            run(FIREWALL, "--add", core)
            firewall_added = True
            run(FIREWALL, "--unblockapp", core)
        child = subprocess.Popen([core, "-d", str(state / "data"), "-f", str(state / "config.json")], **child_args)
        run(ctl, "ready", timeout=180, **child_args)
        if child.wait() != 0:
            raise ValueError("Mihomo exited unexpectedly")
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        try:
            if firewall_added:
                run(FIREWALL, "--remove", core)
        finally:
            if rules:
                disable_pf()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        start(*sys.argv[1:])
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Mihomo launch failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.cmd[0] in (PF, FIREWALL):
            print(error.stderr, file=sys.stderr)
        sys.exit(1)
