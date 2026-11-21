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
unshare --net sleep 30 &
peer=$!
trap 'kill "$peer" 2>/dev/null || true' EXIT
while [[ $(readlink /proc/"$peer"/ns/net) == "$(readlink /proc/self/ns/net)" ]]; do sleep 0.02; done
ip link add home0 type veth peer name client0 netns "$peer"
ip addr add 192.168.0.19/32 dev home0
ip link set home0 up
ip route add 192.168.0.9/32 dev home0
nsenter -t "$peer" -n ip addr add 192.168.0.9/24 dev client0
nsenter -t "$peer" -n ip link set client0 up
nft -f resource/mihomo-home.nft
nft 'add element inet mihomo_home tcp_ports { 17900 }'
nft 'add element inet mihomo_home udp_ports { 1081 }'
python3 - "$peer" <<'PYTHON'
import socket
import subprocess
import sys
import threading

def echo(kind, port):
    with socket.socket(socket.AF_INET, kind) as sock:
        sock.bind(("192.168.0.19", port))
        if kind == socket.SOCK_STREAM:
            sock.listen()
        ready.set()
        while True:
            if kind == socket.SOCK_STREAM:
                conn, _ = sock.accept()
                with conn:
                    conn.sendall(b"ok")
            else:
                _, peer = sock.recvfrom(8)
                sock.sendto(b"ok", peer)

for kind, port in [(socket.SOCK_STREAM, 17900), (socket.SOCK_DGRAM, 1081)]:
    ready = threading.Event()
    threading.Thread(target=echo, args=(kind, port), daemon=True).start()
    assert ready.wait(2)

client = """
import socket,sys
for kind,port in [(socket.SOCK_STREAM,17900),(socket.SOCK_DGRAM,1081)]:
    with socket.socket(socket.AF_INET,kind) as sock:
        sock.settimeout(0.4)
        try:
            sock.connect(('192.168.0.19',port))
            if kind == socket.SOCK_DGRAM: sock.send(b'hi')
            allowed = sock.recv(2) == b'ok'
        except TimeoutError:
            allowed = False
        assert allowed == (sys.argv[1]=='home'), (port,allowed,sys.argv[1])
"""
for location in ("away", "home", "away"):
    rule = 'add element inet mihomo_home home { "home0" timeout 4s }' if location == "home" else "flush set inet mihomo_home home"
    subprocess.run(["nft", rule], check=True)
    subprocess.run(["nsenter", "-t", sys.argv[1], "-n", "python3", "-c", client, location], check=True)
print("PASS: same-subnet client, home-only TCP/UDP, trust removal")
PYTHON
CHECK
