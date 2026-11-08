#!/usr/bin/env python3
"""Usage: test_mihomo_mobile.py GENERATED_YAML PUBLIC_JSON (requires PyYAML)"""
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
import runpy
import json
import sys
import tempfile
from threading import Thread
from urllib.error import HTTPError
from urllib.request import Request, build_opener, ProxyHandler


def check_override(script, public):
    import yaml

    policy = yaml.safe_load(script.read_text())
    pc = json.loads(public.read_text())
    assert set(policy) == {"proxy-groups", "rule-providers", "rules", "dns", "mode", "profile", "tun"}
    assert policy["proxy-groups"] == [g for g in pc["proxy-groups"] if g["name"] != "BENCH"]
    assert policy["rules"] == pc["rules"]
    assert policy["rule-providers"] == pc["rule-providers"]
    assert policy["dns"] == pc["dns"]
    assert policy["mode"] == "rule" and policy["profile"]["store-selected"]
    assert policy["tun"]["enable"]
    groups = {g["name"]: g for g in policy["proxy-groups"]}
    assert len(groups) == len(policy["proxy-groups"])
    assert groups["其他"]["proxies"][0] == "JP"
    assert groups["国内"]["proxies"][0] == "DIRECT"
    assert groups["Telegram"]["proxies"][0] == ("SG" if "SG" in groups else "JP")
    assert groups["GLOBAL"]["default-selected"] == ("SG" if "SG" in groups else "JP")
    assert set(groups["GLOBAL"]["proxies"]) == (groups.keys() - {"GLOBAL"}) | {"DIRECT"}
    assert groups["全部节点"]["filter"] == ".*"
    for name, group in groups.items():
        if name in ("JP", "SG", "全部节点"):
            assert group["include-all"] and group["empty-fallback"] == "REJECT"
            assert "use" not in group
        else:
            assert set(group["proxies"]) <= groups.keys() | {"DIRECT"}
            assert "全部节点" in group["proxies"]
    for rule in policy["rules"]:
        fields = rule.split(",")
        target = fields[-2] if fields[-1] == "no-resolve" else fields[-1]
        assert target in groups.keys() | {"DIRECT", "REJECT"}
        if fields[0] == "RULE-SET":
            assert fields[1] in policy["rule-providers"]
    assert policy["rules"].index("RULE-SET,telegram-ip,Telegram,no-resolve") < policy["rules"].index("RULE-SET,cn-ip,国内")
    assert policy["rules"][-1] == "MATCH,其他"
    assert len({p["path"] for p in policy["rule-providers"].values()}) == len(policy["rule-providers"])
    assert "sub-rules" not in pc
    assert [entry["port"] for entry in pc["listeners"]] == [pc["mixed-port"] + 1, pc["mixed-port"] + 2, 17901]
    assert pc["listeners"][0]["proxy"] == "GLOBAL"


def check_http(script):
    handler = runpy.run_path(str(Path(__file__).with_name("mihomo-mobile.py")))["Handler"]
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        served = root / "clashmi-pc-routing.yaml"
        served.symlink_to(script.resolve())
        with ThreadingHTTPServer(("127.0.0.1", 0), partial(handler, directory=tmp)) as server:
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f"http://127.0.0.1:{server.server_port}"
                client = build_opener(ProxyHandler({}))
                request = Request(url + "/clashmi-pc-routing.yaml", headers={
                    "If-Modified-Since": "Thu, 01 Jan 2099 00:00:00 GMT",
                })
                with client.open(request, timeout=5) as response:
                    assert response.status == 200
                    assert response.headers["Cache-Control"] == "no-store"
                    assert response.headers["Content-Type"] == "application/yaml"
                    assert response.read() == script.read_bytes()
                with client.open(Request(request.full_url, method="HEAD"), timeout=5) as response:
                    assert int(response.headers["Content-Length"]) == script.stat().st_size
                    assert response.read() == b""
                for path in ["/config.json", "/../etc/passwd", "/%2e%2e/etc/passwd"]:
                    try:
                        client.open(url + path, timeout=5)
                    except HTTPError as error:
                        assert error.code == 404
                    else:
                        raise AssertionError(f"Unexpected public file: {path}")
            finally:
                server.shutdown()
                thread.join()


if __name__ == "__main__":
    script, public = map(Path, sys.argv[1:3])
    check_override(script, public)
    check_http(script)
    print("PASS: shared YAML policy, node-source independence, HTTP freshness and file isolation")
