"""Restrict LAN listeners to the verified home uplink."""

import json
import ipaddress
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


def home_prefixes(device):
    prefixes = set()
    for route in read_ip("-6", "route", "show", "table", "main", "dev", device):
        if route.get("gateway") or route.get("dst", "default") == "default":
            continue
        prefix = ipaddress.IPv6Network(route["dst"])
        if prefix.prefixlen < 128 and not (prefix.is_link_local or prefix.is_multicast):
            prefixes.add(prefix)
    return ipaddress.collapse_addresses(prefixes)


def watch(gateway):
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
            if gateway:
                rules += "flush set inet mihomo_home lan6\n"
            if device:
                rules += f"add element inet mihomo_home home {{ {json.dumps(device)} timeout 4s }}\n"
                if gateway:
                    for prefix in home_prefixes(device):
                        rules += f"add element inet mihomo_home lan6 {{ {prefix} timeout 4s }}\n"
            subprocess.run(["nft", "-f", "-"], input=rules, text=True, check=True)
            if poll.select(1):
                monitor.stdout.read(65536)
    sys.exit(1)


if __name__ == "__main__":
    watch("--gateway" in sys.argv[1:])
