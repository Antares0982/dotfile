"""Supervise unprivileged Mihomo behind PF."""

import fcntl
import ipaddress
import json
import os
import plistlib
import pwd
import re
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

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
    if not TOKEN.exists():
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


STATE = Path("/var/db/antares-mihomo")
DNS_BACKUP = STATE / "dns-backup.json"
NETWORK = "/usr/sbin/networksetup"
ROUTE = "/sbin/route"


def managed_chrome(enable):
    path = Path("/Library/Managed Preferences/com.google.Chrome.plist")
    backup = STATE / "chrome-backup.plist"
    if not enable and not backup.exists():
        return
    values = plistlib.loads(path.read_bytes()) if path.exists() else {}
    policy = {"WebRtcIPHandling": "disable_non_proxied_udp", "DnsOverHttpsMode": "off"}
    if enable:
        STATE.mkdir(mode=0o711, exist_ok=True)
        if not backup.exists():
            backup.write_bytes(
                plistlib.dumps({k: values[k] for k in policy if k in values})
            )
        values.update(policy)
    else:
        saved = plistlib.loads(backup.read_bytes())
        for key, value in policy.items():
            if values.get(key) == value:
                values.pop(key)
                if key in saved:
                    values[key] = saved[key]
    path.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as out:
        plistlib.dump(values, out)
        os.fchmod(out.fileno(), 0o644)
    os.replace(out.name, path)
    if not enable:
        backup.unlink()


def physical_uplink():
    rows = run("/usr/sbin/netstat", "-rn", "-f", "inet").stdout.splitlines()
    for row in rows:
        fields = row.split()
        if (
            len(fields) >= 4
            and fields[0] == "default"
            and re.fullmatch(r"(en|bridge)\d+", fields[3])
        ):
            return fields[3], fields[1]
    return None, None


def is_home(device, gateway):
    if not device or gateway != "192.168.0.1":
        return False
    arp = subprocess.run(
        ["/usr/sbin/arp", "-n", gateway], capture_output=True, text=True, check=False
    )
    return bool(
        re.search(
            r" at 9c:47:82:15:10:65 on " + re.escape(device) + r"\b",
            arp.stdout,
            re.IGNORECASE,
        )
    )


def pf_rules(settings, user, device=None, home=False, tunnel=None):
    ports = [settings["mixed-port"]] + [
        l["port"] for l in settings["listeners"] if l["name"] != "bandwidth-test"
    ]
    tcp = "{ " + ", ".join(map(str, ports + [17900])) + " }"
    udp = "{ " + ", ".join(map(str, ports)) + " }"
    rules = ["pass quick on lo0 all no state"]
    if home and settings["allow-lan"]:
        rules += [
            f"pass in quick on {device} inet proto {proto} from 192.168.0.0/24 to ({device}) port {values} no state"
            for proto, values in (("tcp", tcp), ("udp", udp))
        ]
        rules += [
            f"pass out quick on {device} inet proto udp to 192.168.0.1 port 53 user {user} no state"
        ]
    rules += [
        f"block drop in quick proto tcp to self port {tcp}",
        f"block drop in quick proto udp to self port {udp}",
    ]
    if settings["tun"]["enable"]:
        if tunnel:
            rules += [f"pass quick on {tunnel} all no state"]
        rules += [
            "block drop out quick proto { tcp, udp } to 192.168.0.1 port 53",
            f"pass out quick proto {{ tcp, udp }} user {user} keep state",
            "block drop out quick proto { tcp, udp } to any port 53",
            "pass out quick inet proto udp from any port 68 to any port 67 no state",
            "pass out quick inet6 proto udp from any port 546 to any port 547 no state",
            "pass out quick inet6 proto icmp6 icmp6-type { 133, 135, 136 } no state",
        ]
        if home:
            rules += [f"pass out quick on {device} inet to 192.168.0.0/24 no state"]
        rules += ["block drop out quick all"]
    return "\n".join(rules) + "\n"


def protect(settings, uid, device=None, home=False, tunnel=None):
    path = STATE / "guard.pf"
    path.write_text(pf_rules(settings, uid, device, home, tunnel))
    enable_pf(str(path))


def open_tunnel():
    sock = socket.socket(socket.AF_SYSTEM, socket.SOCK_DGRAM, socket.SYSPROTO_CONTROL)
    sock.connect("com.apple.net.utun_control")
    name = sock.getsockopt(socket.SYSPROTO_CONTROL, 2, 64).rstrip(b"\0").decode()
    if not re.fullmatch(r"utun\d+", name):
        raise ValueError("Invalid utun interface")
    run("/sbin/ifconfig", name, "inet", "198.18.0.1", "198.18.0.2", "mtu", "1500", "up")
    run(
        "/sbin/ifconfig",
        name,
        "inet6",
        "fdfe:dcba:9876::1",
        "prefixlen",
        "126",
        "alias",
    )
    # Preserve Darwin's zero-address default-route lookup.
    for family, default, reserved in (
        ("-inet", "0.0.0.0/0", "0.0.0.0/8"),
        ("-inet6", "::/0", "::/16"),
    ):
        for prefix in ipaddress.ip_network(default).address_exclude(
            ipaddress.ip_network(reserved)
        ):
            run(ROUTE, "-n", "add", family, "-net", str(prefix), "-interface", name)
    return sock, name


def service_name(device):
    output = run(NETWORK, "-listnetworkserviceorder").stdout
    match = re.search(
        r"^\(\d+\) ([^\n]+)\n\(Hardware Port: [^\n]*, Device: "
        + re.escape(device)
        + r"\)",
        output,
        re.MULTILINE,
    )
    if not match:
        raise ValueError("No network service for " + device)
    return match[1]


def save_dns(saved):
    if saved:
        backup = DNS_BACKUP.with_suffix(".tmp")
        backup.write_text(json.dumps(saved))
        backup.replace(DNS_BACKUP)
    else:
        DNS_BACKUP.unlink(missing_ok=True)


def set_dns(device):
    saved = json.loads(DNS_BACKUP.read_text()) if DNS_BACKUP.exists() else {}
    service = service_name(device) if device else None
    for old in list(saved):
        if old != service:
            current = run(NETWORK, "-getdnsservers", old).stdout.splitlines()
            if current == ["198.18.0.2"]:
                run(NETWORK, "-setdnsservers", old, *(saved[old] or ["Empty"]))
            del saved[old]
            save_dns(saved)
    if service:
        current = run(NETWORK, "-getdnsservers", service).stdout.splitlines()
        if current != ["198.18.0.2"]:
            if service not in saved:
                saved[service] = (
                    [] if current and current[0].startswith("There aren't") else current
                )
                save_dns(saved)
            run(NETWORK, "-setdnsservers", service, "198.18.0.2")


def start(template, subscription, prepare, core, ctl):
    os.umask(0o077)
    STATE.mkdir(mode=0o711, exist_ok=True)
    os.chmod(STATE, 0o711)
    lock = (STATE / "supervisor.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX)
    login = pwd.getpwnam("antares")
    worker = pwd.getpwnam("_mihomo")
    user_args = {
        "user": login.pw_uid,
        "group": login.pw_gid,
        "extra_groups": [],
        "env": os.environ | {"HOME": login.pw_dir},
    }
    old = Path(login.pw_dir) / "Library/Application Support/mihomo"
    settings = json.loads(Path(template).read_text())
    guarded = settings["tun"]["enable"] or settings["allow-lan"]
    if guarded:
        protect(settings, worker.pw_uid)
        first, router = physical_uplink()
        protect(settings, worker.pw_uid, first, is_home(first, router))
    if not settings["tun"]["enable"] and DNS_BACKUP.exists():
        set_dns(None)
    ports = [
        (settings["bind-address"], settings["mixed-port"], kind)
        for kind in (socket.SOCK_STREAM, socket.SOCK_DGRAM)
    ]
    for listener in settings["listeners"]:
        ports.append((listener["listen"], listener["port"], socket.SOCK_STREAM))
        if listener.get("udp"):
            ports.append((listener["listen"], listener["port"], socket.SOCK_DGRAM))
    ports.append(
        (settings["external-controller"].split(":")[0], 17900, socket.SOCK_STREAM)
    )
    wait_ports(ports)
    run(sys.executable, prepare, template, subscription, **user_args)
    private = json.loads(run("/bin/cat", str(old / "config.json"), **user_args).stdout)
    data = STATE / "data"
    if not data.exists():
        with tempfile.TemporaryDirectory(dir=STATE) as staging:
            fresh = Path(staging) / "data"
            fresh.mkdir()
            original = old / "data/cache.db"
            if original.is_file():
                with (fresh / "cache.db").open("wb") as out:
                    subprocess.run(
                        ["/bin/cat", str(original)], check=True, stdout=out, **user_args
                    )
                os.chown(fresh / "cache.db", worker.pw_uid, worker.pw_gid)
            os.chown(fresh, worker.pw_uid, worker.pw_gid)
            fresh.rename(data)
    device, gateway = physical_uplink()
    home = is_home(device, gateway)
    tun = child = ready = None
    try:
        name = None
        if settings["tun"]["enable"]:
            if not device:
                raise ValueError("No physical uplink")
            tun, name = open_tunnel()
            private["tun"].update({"file-descriptor": tun.fileno(), "device": name})
            private["interface-name"] = device
            set_dns(device)
        if guarded:
            protect(settings, worker.pw_uid, device, home, name)
        path = STATE / "config.json"
        path.write_text(json.dumps(private, ensure_ascii=False))
        os.chown(path, 0, worker.pw_gid)
        path.chmod(0o640)
        if settings["allow-lan"]:
            run(FIREWALL, "--add", core)
            run(FIREWALL, "--unblockapp", core)
        child = subprocess.Popen(
            [core, "-d", str(data), "-f", str(path)],
            user=worker.pw_uid,
            group=worker.pw_gid,
            extra_groups=[],
            pass_fds=(tun.fileno(),) if tun else (),
        )
        ready = subprocess.Popen([ctl, "ready"], **user_args)
        deadline = time.monotonic() + 180
        while child.poll() is None:
            if ready is not None:
                status = ready.poll()
                if status == 0:
                    ready = None
                elif status is not None or time.monotonic() >= deadline:
                    raise ValueError("Mihomo bootstrap failed")
            time.sleep(1)
            uplink, router = physical_uplink()
            trusted = is_home(uplink, router)
            if (uplink, router) != (device, gateway):
                break
            if trusted != home:
                home = trusted
                protect(settings, worker.pw_uid, device, home, name)
        raise ValueError("Mihomo exited or uplink changed")
    finally:
        try:
            if guarded:
                # Close old-interface access before cleanup.
                protect(settings, worker.pw_uid)
                first, router = physical_uplink()
                if is_home(first, router):
                    protect(settings, worker.pw_uid, first, True)
        finally:
            if ready is not None and ready.poll() is None:
                ready.kill()
                ready.wait()
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
            if tun:
                tun.close()
            if settings["allow-lan"]:
                run(FIREWALL, "--remove", core)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    if len(sys.argv) == 3 and sys.argv[1] == "chrome":
        managed_chrome(sys.argv[2] == "on")
    elif sys.argv[1:] == ["cleanup"]:
        if DNS_BACKUP.exists():
            set_dns(None)
        if TOKEN.exists():
            disable_pf()
    else:
        start(*sys.argv[1:])
