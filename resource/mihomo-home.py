"""Restrict LAN listeners to the verified home uplink."""

import json
import selectors
import subprocess
import sys

GATEWAY = "192.168.0.1"
ROUTER = "9c:47:82:15:10:65"


def read_ip(*args):
    return json.loads(subprocess.check_output(["ip", "-j", *args]))


def home_interface():
    for route in read_ip("route", "show", "default"):
        if route.get("gateway") != GATEWAY:
            continue
        device = route["dev"]
        neighbors = read_ip("neigh", "show", "to", GATEWAY, "dev", device)
        if any(
            n.get("lladdr") == ROUTER
            and not {"FAILED", "INCOMPLETE"}.intersection(n["state"])
            for n in neighbors
        ):
            return device
    return None


def watch():
    with (
        subprocess.Popen(
            ["ip", "monitor", "link", "route", "neigh"],
            stdout=subprocess.PIPE,
            bufsize=0,
        ) as monitor,
        selectors.DefaultSelector() as poll,
    ):
        poll.register(monitor.stdout, selectors.EVENT_READ)
        while monitor.poll() is None:
            device = home_interface()
            rules = "flush set inet mihomo_home home\n"
            if device:
                rules += f"add element inet mihomo_home home {{ {json.dumps(device)} timeout 4s }}\n"
            subprocess.run(["nft", "-f", "-"], input=rules, text=True, check=True)
            if poll.select(1):
                monitor.stdout.read(65536)
    sys.exit(1)


if __name__ == "__main__":
    watch()
