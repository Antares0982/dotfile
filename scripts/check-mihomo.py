#!/usr/bin/env python3
"""Live acceptance for the installed Mihomo service."""

import argparse
import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import time
import urllib.error
import urllib.request

spec = importlib.util.spec_from_file_location(
    "mihomo", Path(__file__).resolve().parents[1] / "resource/mihomo-tools.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def trace(proxy=None, family=None):
    command = [
        "curl",
        "-q",
        "-fsS",
        "--connect-timeout",
        "10",
        "--max-time",
        "30",
        "--noproxy",
        "" if proxy else "*",
    ]
    if proxy:
        command += ["--proxy", proxy]
    if family:
        command.append(f"-{family}")
    result = subprocess.run(
        command + ["https://www.cloudflare.com/cdn-cgi/trace"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"curl failed: {proxy} ({result.returncode})"
    return dict(
        line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
    )


def route(port, host, outbound=None):
    with socket.create_connection((m.client_address(), port), timeout=15) as sock:
        source_port = sock.getsockname()[1]
        sock.sendall(
            f"CONNECT {host}:443 HTTP/1.1\r\nHost: {host}:443\r\n\r\n".encode()
        )
        assert b"200" in sock.recv(4096), f"CONNECT failed for {host}"
        for _ in range(150):
            matches = [
                c
                for c in m.request("/connections")["connections"]
                if str(c["metadata"]["sourcePort"]) == str(source_port)
            ]
            if matches:
                match = matches[0]
                if outbound is None:
                    assert match["rule"], f"No routing rule matched {host}"
                else:
                    assert outbound in match["chains"], (host, match["chains"])
                print(f"{port} {host}: {match['rule']} -> {match['chains'][0]}")
                return match["chains"][0]
            time.sleep(0.1)
        raise AssertionError(f"No active connection found for {host}")


def check(webui=True):
    client = m.connection()
    config = m.request("/configs")
    assert config["mode"] == "rule"
    assert config["mixed-port"] == client["port"]
    proxies = m.request("/proxies")["proxies"]
    regions = m.execute({"action": "status"})
    for name in regions:
        assert proxies[name]["now"] in proxies[name]["all"]
        assert not {"DIRECT", "COMPATIBLE", "REJECT"}.intersection(proxies[name]["all"])
        result = m.probe_node(proxies[name]["now"])
        assert result["loc"] == name, (name, result["loc"])
        print(f"{name} selected node: {result['loc']}")

    def outbound(name):
        seen = set()
        while name not in (*regions, "DIRECT", "REJECT") and "now" in proxies.get(
            name, {}
        ):
            assert name not in seen, "Cyclic policy group"
            seen.add(name)
            name = proxies[name]["now"]
        return name

    providers = m.request("/providers/rules")["providers"]
    assert all(r["ruleCount"] > 0 for r in providers.values())
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    if webui:
        with opener.open(client["api"] + "/ui/", timeout=10) as response:
            assert b"MetaCubeXD" in response.read()
    else:
        request = urllib.request.Request(
            client["api"] + "/ui/",
            headers={"Authorization": "Bearer " + client["secret"]},
        )
        try:
            opener.open(request, timeout=10)
        except urllib.error.HTTPError as error:
            assert error.code == 404
        else:
            raise AssertionError("Unexpected WebUI on headless host")
    try:
        opener.open(client["api"] + "/proxies", timeout=10)
    except urllib.error.HTTPError as error:
        assert error.code == 401
    else:
        raise AssertionError("Missing API authentication")
    countries = {name: name for name in regions}
    tun = config.get("tun", {}).get("enable", False)
    direct = client["port"] + 2
    if tun:
        route(direct, "www.cloudflare.com", "DIRECT")
    countries["DIRECT"] = trace(
        f"http://{m.client_address()}:{direct}" if tun else None
    )["loc"]
    rule_target = route(client["port"], "www.cloudflare.com")
    for offset, target in enumerate([rule_target, outbound("GLOBAL"), "DIRECT"]):
        if target not in countries:
            countries[target] = m.probe_node(target)["loc"]
        country = countries[target]
        port = client["port"] + offset
        if tun and offset == 0:
            for family in (4, 6):
                assert trace(family=family)["loc"] == country, (
                    f"Unexpected IPv{family} TUN egress"
                )
        for protocol in ("http", "socks5h"):
            result = trace(f"{protocol}://{m.client_address()}:{port}")
            assert result["loc"] == country, (port, result["loc"], country)
            print(f"{port} {protocol}: {result['loc']} {result['ip']}")
    route(client["port"] + 1, "www.cloudflare.com", outbound("GLOBAL"))
    with socket.socket() as sock:
        assert sock.connect_ex((m.client_address(), client["port"] + 3)) != 0, (
            "Retired port still listening"
        )
    print(
        "PASS: protocols, regions, routing, rule providers, dashboard policy and API authentication"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--no-webui", action="store_true", help="expect no WebUI (HK/SZ)"
    )
    check(webui=not parser.parse_args().no_webui)
