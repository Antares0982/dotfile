#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
unshare --net -- bash -euo pipefail <<'CHECK'
ip link add uplink type dummy
ip link set uplink up
ip addr add 192.168.0.2/24 dev uplink
ip -6 addr add 2001:db8::1/64 dev uplink nodad
ip route add default dev uplink
ip -6 route add default dev uplink
nft -f resource/mihomo-guard.nft
python3 - <<'PY'
import json
import os
import socket
import subprocess

def drops():
    data = json.loads(subprocess.check_output(["nft", "-j", "list", "chain", "inet", "mihomo_guard", "egress"]))
    return sum(expr["counter"]["packets"] for item in data["nftables"]
               for expr in item.get("rule", {}).get("expr", []) if "counter" in expr)

def send(host, port):
    family = socket.AF_INET6 if ":" in host else socket.AF_INET
    with socket.socket(family, socket.SOCK_DGRAM) as sock:
        sock.sendto(b"test", (host, port))

for host, port in [("203.0.113.1", 443), ("2001:db8::2", 443), ("192.168.0.1", 53)]:
    before = drops()
    try:
        send(host, port)
    except PermissionError:
        pass
    assert drops() > before, (host, port)
before = drops()
send("192.168.0.3", 445)
assert drops() == before
subprocess.run(["nft", "add", "element", "inet", "mihomo_guard", "core", f"{{ {os.getuid()} }}"], check=True)
subprocess.run(["nft", "-f", "resource/mihomo-guard.nft"], check=True)
send("203.0.113.1", 443)
assert drops() == 0, "Reload lost the active service identity"
print("PASS: IPv4/IPv6 egress, LAN DNS, LAN access and firewall reload")
PY
CHECK
