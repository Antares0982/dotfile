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

unshare --net sleep 60 &
remote=$!
trap 'kill "$peer" "$remote" 2>/dev/null || true' EXIT
while [[ $(readlink /proc/"$remote"/ns/net) == "$(readlink /proc/self/ns/net)" ]]; do sleep 0.02; done
ip link add mihomo0 type veth peer name server0 netns "$remote"
ip link set mihomo0 up
ip addr add 198.18.0.1/30 dev mihomo0
ip -6 addr add fdfe:dcba:9876::1/126 dev mihomo0 nodad
ip -6 addr add 2001:db8:1::19/64 dev home0 nodad
client() { nsenter -t "$peer" -n "$@"; }
server() { nsenter -t "$remote" -n "$@"; }
client ip -6 addr add 2001:db8:1::9/64 dev client0 nodad
client ip route add default via 192.168.0.19
client ip -6 route add default via 2001:db8:1::19
server ip link set server0 up
server ip addr add 198.18.0.2/30 dev server0
server ip -6 addr add fdfe:dcba:9876::2/126 dev server0 nodad
server ip route add default via 198.18.0.1
server ip -6 route add default via fdfe:dcba:9876::1
sysctl -qw net.ipv4.conf.all.forwarding=1 net.ipv6.conf.all.forwarding=1
nft -f resource/mihomo-gateway-guard.nft
nft -f resource/mihomo-gateway.nft
nft 'flush set inet mihomo_guard core'
ip46tables() { iptables "$@"; ip6tables "$@"; }
ip46tables -N nixos-fw
ip46tables -N nixos-fw-accept
ip46tables -A nixos-fw-accept -j ACCEPT
ip46tables -A INPUT -j nixos-fw
ip46tables -t mangle -N nixos-fw-rpfilter
ip46tables -t mangle -A PREROUTING -j nixos-fw-rpfilter
# Model asymmetric TUN return routes.
ip46tables -t mangle -A nixos-fw-rpfilter -i mihomo0 -p udp -j DROP
source resource/mihomo-gateway-firewall.sh
ip46tables -A nixos-fw -i home0 -p tcp -j DROP
nft 'add table inet test_proxy'
nft 'add chain inet test_proxy redirect_tcp { type nat hook prerouting priority dstnat + 1; }'
nft 'add rule inet test_proxy redirect_tcp iifname "home0" tcp dport 443 redirect to :14443'
nft 'add element inet mihomo_home lan6 { 2001:db8:1::/64 timeout 1m }'
nft 'add element inet mihomo_home home { "home0" timeout 1m }'
python3 - "$peer" "$remote" <<'PYTHON'
import socket
import subprocess
import sys
import threading

def echo_tcp(listener):
    while True:
        conn, _ = listener.accept()
        with conn:
            conn.sendall(b"ok")

udp = """
import socket
with socket.socket(socket.AF_INET6, socket.SOCK_DGRAM) as sock:
    sock.bind(('::', 53))
    print('ready', flush=True)
    while True:
        data, addr = sock.recvfrom(32)
        sock.sendto(data, addr)
"""
probe = """
import socket, sys
for host in ('198.18.0.2', 'fdfe:dcba:9876::2'):
    for kind, port in [(socket.SOCK_STREAM, 443), (socket.SOCK_DGRAM, 53)]:
        family = socket.AF_INET6 if ':' in host else socket.AF_INET
        with socket.socket(family, kind) as sock:
            sock.settimeout(3 if sys.argv[1] == "home" else 0.35)
            try:
                sock.connect((host, port))
                if kind == socket.SOCK_DGRAM:
                    sock.send(b'ok')
                allowed = sock.recv(2) == b'ok'
            except OSError:
                allowed = False
            expected = sys.argv[1] == 'home' or (sys.argv[1] == 'old-prefix' and family == socket.AF_INET)
            assert allowed == expected, (host, port, sys.argv[1])
"""
with socket.create_server(("::", 14443), family=socket.AF_INET6, dualstack_ipv6=True) as listener:
    threading.Thread(target=echo_tcp, args=(listener,), daemon=True).start()
    server = subprocess.Popen(["nsenter", "-t", sys.argv[2], "-n", "python3", "-c", udp],
                              stdout=subprocess.PIPE, text=True)
    try:
        assert server.stdout.readline().strip() == "ready"
        for case in ("home", "old-prefix", "away", "stopped"):
            if case == "old-prefix":
                subprocess.run(["nft", "flush set inet mihomo_home lan6"], check=True)
            if case == "away":
                subprocess.run(["nft", "flush set inet mihomo_home home"], check=True)
            if case == "stopped":
                subprocess.run(["nft", 'add element inet mihomo_home home { "home0" timeout 1m }'], check=True)
                subprocess.run(["nft", 'add element inet mihomo_home lan6 { 2001:db8:1::/64 timeout 1m }'], check=True)
                subprocess.run(["nft", "delete table inet test_proxy"], check=True)
                subprocess.run(["ip", "link", "set", "mihomo0", "down"], check=True)
            subprocess.run(["nsenter", "-t", sys.argv[1], "-n", "python3", "-c", probe, case], check=True)
        import json
        rules = json.loads(subprocess.check_output(["nft", "-j", "list", "chain", "inet", "mihomo_home", "gateway_forward"]))
        assert any(expr.get("counter", {}).get("packets", 0) > 0 for item in rules["nftables"]
                   for expr in item.get("rule", {}).get("expr", [])), "Missing physical fallback drop"
    finally:
        server.terminate()
        server.wait()
print("PASS: dual-stack redirected TCP, forwarded UDP/DNS, home trust and physical fallback")
PYTHON
CHECK
