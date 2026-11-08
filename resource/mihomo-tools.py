"""Mihomo control, isolated throughput probes and restricted agent transport."""

import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import uuid

STATE = Path.home() / "Library/Application Support/mihomo" if sys.platform == "darwin" else None
CLIENT = STATE / "client/connection.json" if sys.platform == "darwin" else Path("/run/mihomo-client/connection.json")
LOCK = STATE / "speed-test.lock" if sys.platform == "darwin" else Path("/run/lock/mihomo-speed-test.lock")
QUEUE = Path("/home/agent/agent_work/.agent/mihomo")
URL = "https://speed.cloudflare.com/__down?bytes=100000000"
PARAMS = {"quick_seconds": 3, "final_seconds": 5, "connect_seconds": 2, "finalists": 3}


def publish(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump(value, stream, ensure_ascii=False, allow_nan=False)
            os.fchmod(stream.fileno(), 0o660 if str(path).startswith(str(QUEUE)) else 0o600)
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def connection():
    credentials = os.environ.get("CREDENTIALS_DIRECTORY")
    path = Path(credentials) / "connection.json" if credentials else CLIENT
    if credentials and not path.exists():
        config = json.loads((Path(credentials) / "config.yaml").read_text())
        return {"api": "http://127.0.0.1:17900", "secret": config["secret"],
                "port": config["mixed-port"], "test_port": 17901}
    return json.loads(path.read_text())


def request(path, method="GET", data=None):
    client = connection()
    req = urllib.request.Request(
        client["api"] + path, method=method,
        data=None if data is None else json.dumps(data).encode(),
        headers={"Authorization": "Bearer " + client["secret"], "Content-Type": "application/json"},
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(req, timeout=60) as response:
        body = response.read()
    return json.loads(body) if body else None


def group(name):
    if name not in ("JP", "SG", "BENCH"):
        raise ValueError("Unknown proxy group")
    return request("/proxies/" + name)


def select(name, node):
    if node not in group(name)["all"] or node in ("DIRECT", "REJECT", "COMPATIBLE"):
        raise ValueError("Node is not a member of the requested region")
    request("/proxies/" + name, "PUT", {"name": node})
    if group(name)["now"] != node:
        raise ValueError("Node selection was not applied")
    return {"group": name, "node": node}


def sample(node, seconds):
    started = time.monotonic()
    value = {"node": node, "valid": False}
    try:
        select("BENCH", node)
        result = subprocess.run([
            "curl", "-q", "-sS", "-o", os.devnull, "--noproxy", "",
            "--proxy", f"http://127.0.0.1:{connection()['test_port']}",
            "--connect-timeout", str(PARAMS["connect_seconds"]), "--max-time", str(seconds),
            "--referer", "https://speed.cloudflare.com/", "--url", URL,
            "--write-out", "%{http_code} %{speed_download} %{size_download} %{time_total} %{time_starttransfer}",
        ], capture_output=True, text=True, timeout=seconds + 3)
        http, rate, size, duration, first = map(float, result.stdout.split())
        if not all(math.isfinite(v) for v in (http, rate, size, duration, first)):
            raise ValueError("Nonfinite measurement")
        valid = http == 200 and rate > 0 and size > 0 and duration > 0 and (
            result.returncode == 0 or (result.returncode == 28 and duration - first >= 1)
        )
        value.update(valid=valid, http=int(http), curl_status=result.returncode,
                     bytes_per_second=rate, mbps=rate * 8 / 1000000,
                     bytes=size, seconds=duration, time_starttransfer=first)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    if not value["valid"]:
        value["error"] = "Node selection or download failed"
    value["wall_seconds"] = time.monotonic() - started
    return value


def measure(region, refresh=False):
    started = time.monotonic()
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "mihomo-speed-test"
    cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Host-wide lock prevents overlapping bandwidth measurements.
    with open(LOCK, "r+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        candidates = sorted(n for n in group(region)["all"] if n not in ("REJECT", "COMPATIBLE", "DIRECT"))
        if not candidates:
            raise ValueError("No nodes in this region")
        provider = request("/providers/proxies/subscription")
        identity = [region, candidates, provider.get("updatedAt"), URL, PARAMS]
        key = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        cache_file = cache_dir / (key + ".json")
        if not refresh and cache_file.exists():
            try:
                cached = json.loads(cache_file.read_text())
                if cached.get("results") and 0 <= time.time() - cached["created_at"] < 600:
                    return cached | {"cached": True}
            except (OSError, ValueError, KeyError, TypeError):
                pass
        previous = group("BENCH")["now"]
        try:
            quick = []
            for node in candidates:
                print(f"Quick: {node}", file=sys.stderr, flush=True)
                quick.append(sample(node, PARAMS["quick_seconds"]))
            best = sorted((s for s in quick if s["valid"]), key=lambda s: -s["bytes_per_second"])[:3]
            final = []
            for entry in best:
                print(f"Final: {entry['node']}", file=sys.stderr, flush=True)
                final.append(sample(entry["node"], PARAMS["final_seconds"]))
        finally:
            if previous in group("BENCH")["all"]:
                select("BENCH", previous)
        result = {"version": 1, "region": region, "created_at": time.time(), "cached": False,
                  "parameters": PARAMS, "quick": quick, "final": final,
                  "results": sorted((s for s in final if s["valid"]), key=lambda s: -s["bytes_per_second"]),
                  "wall_seconds": time.monotonic() - started}
        if result["results"]:
            publish(cache_file, result)
        return result


def probe_node(node):
    with open(LOCK, "r+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = group("BENCH")["now"]
        try:
            select("BENCH", node)
            check = subprocess.run([
                "curl", "-q", "-fsS", "--noproxy", "", "--connect-timeout", "10", "--max-time", "30",
                "--proxy", f"http://127.0.0.1:{connection()['test_port']}", "https://www.cloudflare.com/cdn-cgi/trace",
            ], capture_output=True, text=True, timeout=35)
            if check.returncode:
                raise ValueError("Could not verify node egress")
            return dict(line.split("=", 1) for line in check.stdout.splitlines() if "=" in line)
        finally:
            if previous in group("BENCH")["all"]:
                select("BENCH", previous)


def execute(value):
    action = value["action"]
    if action == "status":
        proxies = request("/proxies")["proxies"]
        return {n: {"node": proxies[n]["now"], "nodes": proxies[n]["all"]} for n in ("JP", "SG") if n in proxies}
    if action == "select":
        name = value["group"]
        previous = group(name)["now"]
        result = select(name, value["node"])
        try:
            trace = probe_node(value["node"])
            if trace.get("loc") != name or not trace.get("ip"):
                raise ValueError("Could not verify regional egress")
            return result | {"ip": trace["ip"], "country": trace["loc"]}
        except (OSError, ValueError, subprocess.TimeoutExpired):
            if previous in group(name)["all"] and previous not in ("REJECT", "COMPATIBLE", "DIRECT"):
                select(name, previous)
            raise ValueError("Egress failed; restored previous selection where available") from None
    if action == "speed":
        return measure(value["group"], value["refresh"])
    if action == "update":
        request("/providers/proxies/subscription", "PUT")
    elif action == "restart":
        request("/restart", "POST", {})
    else:
        raise ValueError("Unknown action")
    return {"action": action, "ok": True}


def ready():
    deadline = time.monotonic() + 120
    while True:
        if time.monotonic() >= deadline:
            raise ValueError("Mihomo bootstrap timed out")
        try:
            proxies = request("/proxies")["proxies"]
            if any(proxies[name]["all"] == ["REJECT"] for name in ("JP", "SG") if name in proxies):
                request("/providers/proxies/subscription", "PUT")
                time.sleep(2)
                continue
            rules = request("/providers/rules")["providers"]
            for name, provider in rules.items():
                if provider["ruleCount"] == 0:
                    request("/providers/rules/" + urllib.parse.quote(name, safe=""), "PUT")
            if not all(p["ruleCount"] > 0 for p in request("/providers/rules")["providers"].values()):
                raise ValueError("Rules are not ready")
            return
        except (OSError, ValueError, KeyError):
            if time.monotonic() >= deadline:
                raise ValueError("Mihomo bootstrap timed out") from None
            time.sleep(2)


def valid_request(value, token):
    fields = {"status": set(), "update": set(), "restart": set(),
              "select": {"group", "node"}, "speed": {"group", "refresh"}}
    if not isinstance(value, dict) or not isinstance(value.get("action"), str) or value["action"] not in fields:
        return False
    if set(value) != {"id", "action"} | fields[value["action"]] or value["id"] != token:
        return False
    if "group" in value and value["group"] != "JP":
        return False
    if "node" in value and (not isinstance(value["node"], str) or not 0 < len(value["node"]) <= 256):
        return False
    return "refresh" not in value or type(value["refresh"]) is bool


def worker():
    os.umask(0o007)
    with (QUEUE / "worker.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for path in (QUEUE / "processing").glob("*.json"):
            path.rename(QUEUE / "requests" / path.name)
        while pending := sorted((QUEUE / "requests").glob("*.json")):
            for path in pending:
                token = path.stem
                if len(token) != 32 or any(c not in "0123456789abcdef" for c in token):
                    path.unlink()
                    continue
                claimed = QUEUE / "processing" / path.name
                path.rename(claimed)
                try:
                    if claimed.is_symlink() or claimed.stat().st_size > 4096:
                        raise ValueError("Invalid request file")
                    value = json.loads(claimed.read_text())
                    if not valid_request(value, token):
                        raise ValueError("Invalid request")
                    result = {"id": token, "result": execute(value)}
                except (OSError, ValueError, KeyError, TypeError):
                    result = {"id": token, "error": "Mihomo request failed"}
                publish(QUEUE / "results" / path.name, result)
                claimed.unlink()
        for path in (QUEUE / "results").glob("*.json"):
            if time.time() - path.stat().st_mtime > 86400:
                path.unlink()


def via_worker(value):
    token = uuid.uuid4().hex
    value = value | {"id": token}
    if not valid_request(value, token):
        raise ValueError("Invalid worker request")
    # Publish complete requests before waking systemd.
    temporary = QUEUE / (token + ".json")
    publish(temporary, value)
    temporary.rename(QUEUE / "requests" / temporary.name)
    result_file = QUEUE / "results" / temporary.name
    deadline = time.monotonic() + 900
    notice = 0
    while time.monotonic() < deadline:
        if result_file.exists():
            result = json.loads(result_file.read_text())
            if result.get("id") != token or "error" in result:
                raise ValueError("Worker failed; proxy selection unconfirmed")
            result_file.unlink()
            return result["result"]
        if time.monotonic() >= notice:
            print("Waiting for Mihomo worker…", file=sys.stderr, flush=True)
            notice = time.monotonic() + 10
        time.sleep(0.2)
    raise ValueError("Worker timed out; do not reuse earlier results")


def tui():
    client = connection()
    directory = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "mihomo-tui"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    for engine in ("mihomo", "sing-box"):
        for name in ("profiles", "templates", "provider-cache", "proxy-providers"):
            (directory / engine / name).mkdir(parents=True, exist_ok=True)
    publish(directory / "config.yaml", {"mihomo": {
        "core": {"config_dir": str(directory / "unused-core"),
                 "config_path": str(directory / "unused-core/config.json"),
                 "bin_path": os.environ["MIHOMO_BIN"]},
        "core_service": {"service_name": "org.nixos.mihomo" if sys.platform == "darwin" else "mihomo", "is_user": False},
    }})
    publish(directory / "mihomo/core_override_config.yaml", {
        "external-controller": "127.0.0.1:17900", "secret": client["secret"], "mixed-port": client["port"],
    })
    for key in ("no_proxy", "NO_PROXY"):
        os.environ[key] = ",".join(filter(None, (os.environ.get(key), "127.0.0.1", "localhost")))
    os.execv(os.environ["CLASHTUI_BIN"], ["clashtui", f"--config-dir={directory}"])


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--via-worker", action="store_true")
    if os.environ.get("MIHOMO_COMMAND") == "mihomo-speed-test":
        parser.add_argument("group", choices=("JP", "SG"), default="JP", nargs="?")
        parser.add_argument("--refresh", action="store_true")
        args = parser.parse_args()
        value = {"action": "speed", "group": args.group, "refresh": args.refresh}
    else:
        parser.add_argument("action", choices=("tui", "status", "select", "update", "secret", "restart", "worker", "ready"))
        parser.add_argument("group", nargs="?", choices=("JP", "SG"))
        parser.add_argument("node", nargs="?")
        args = parser.parse_args()
        if args.action == "worker":
            worker()
            return
        if args.action == "ready":
            ready()
            return
        if args.action in ("secret", "tui"):
            if args.via_worker:
                parser.error("This action is local only")
            return tui() if args.action == "tui" else print(connection()["secret"])
        value = {"action": args.action}
        if args.action == "select":
            if args.group is None or args.node is None:
                parser.error("select requires GROUP NODE")
            value.update(group=args.group, node=args.node)
    result = via_worker(value) if args.via_worker else execute(value)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if value["action"] == "speed" and not result["results"]:
        sys.exit(1)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(130))
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, ValueError, KeyError, TypeError) as error:
        # Avoid printing subscription or credential data.
        print(f"Mihomo command failed ({type(error).__name__})", file=sys.stderr)
        sys.exit(1)
