#!/usr/bin/env python3
"""Live acceptance for the installed Mihomo service."""

import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import time
import urllib.error
import urllib.request

spec = importlib.util.spec_from_file_location("mihomo", Path(__file__).resolve().parents[1] / "resource/mihomo-tools.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def trace(proxy=None):
    command = ["curl", "-q", "-fsS", "--connect-timeout", "10", "--max-time", "30", "--noproxy", "" if proxy else "*"]
    if proxy:
        command += ["--proxy", proxy]
    result = subprocess.run(command + ["https://www.cloudflare.com/cdn-cgi/trace"], capture_output=True, text=True)
    assert result.returncode == 0, f"curl failed: {proxy} ({result.returncode})"
    return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)


def route(port, host, outbound):
    with socket.create_connection(("127.0.0.1", port), timeout=15) as sock:
        source_port = sock.getsockname()[1]
        sock.sendall(f"CONNECT {host}:443 HTTP/1.1\r\nHost: {host}:443\r\n\r\n".encode())
        assert b"200" in sock.recv(4096), f"CONNECT failed for {host}"
        for _ in range(150):
            matches = [c for c in m.request("/connections")["connections"]
                       if str(c["metadata"]["sourcePort"]) == str(source_port)]
            if matches:
                assert outbound in matches[0]["chains"], (host, matches[0]["chains"])
                print(f"{port} {host}: {matches[0]['rule']} -> {outbound}")
                return
            time.sleep(0.1)
        raise AssertionError(f"No active connection found for {host}")


def check():
    client = m.connection()
    config = m.request("/configs")
    assert config["mode"] == "rule"
    assert config["mixed-port"] == client["port"]
    proxies = m.request("/proxies")["proxies"]
    regions = [name for name in ("JP", "SG") if name in proxies]
    for name in regions:
        assert proxies[name]["now"] in proxies[name]["all"]
        assert not {"DIRECT", "COMPATIBLE", "REJECT"}.intersection(proxies[name]["all"])
    rules = m.request("/providers/rules")["providers"]
    assert len(rules) == 8 and all(r["ruleCount"] > 0 for r in rules.values())
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(client["api"] + "/ui/", timeout=10) as response:
        assert b"MetaCubeXD" in response.read()
    try:
        opener.open(client["api"] + "/proxies", timeout=10)
    except urllib.error.HTTPError as error:
        assert error.code == 401
    else:
        raise AssertionError("Missing API authentication")
    direct = trace()["loc"]
    for offset, country in enumerate(["JP", "JP", direct] + (["SG"] if "SG" in regions else [])):
        port = client["port"] + offset
        for protocol in ("http", "socks5h"):
            result = trace(f"{protocol}://127.0.0.1:{port}")
            assert result["loc"] == country, (port, result["loc"], country)
            print(f"{port} {protocol}: {result['loc']} {result['ip']}")
    route(client["port"], "www.baidu.com", "DIRECT")
    route(client["port"], "claude.ai", "JP")
    route(client["port"] + 1, "www.baidu.com", "JP")
    if "SG" in regions:
        route(client["port"] + 3, "www.baidu.com", "DIRECT")
        route(client["port"] + 3, "chatgpt.com", "SG")
    rejected = subprocess.run(["curl", "-q", "-fsS", "--max-time", "10", "--noproxy", "",
                               "--proxy", f"http://127.0.0.1:{client['port']}", "https://id6.me"], capture_output=True)
    assert rejected.returncode != 0, "Carrier authentication domain was not blocked"
    print("PASS: protocols, regions, routing, rule providers, Web UI and API authentication")


if __name__ == "__main__":
    check()
