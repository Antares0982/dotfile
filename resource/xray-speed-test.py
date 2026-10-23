"""Unprivileged, sequential Xray throughput probes and agent request transport."""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import uuid

URL = "https://speed.cloudflare.com/__down?bytes=100000000"
QUEUE = Path("/home/agent/agent_work/.agent/xray-speed-test")
PARAMS = {"quick_seconds": 3, "final_seconds": 5, "connect_seconds": 2,
          "startup_seconds": 5, "finalists": 3}


def publish(path, value, staging=None):
    with tempfile.NamedTemporaryFile(mode="w", dir=staging or path.parent, delete=False) as stream:
        temp = Path(stream.name)
        try:
            json.dump(value, stream, allow_nan=False)
            stream.close()
            os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)


def nodes(subscriptions, pattern):
    return sorted((p for p in subscriptions.glob("*.json")
                   if p.name != "active.json" and not p.is_symlink()
                   and p.is_file() and pattern in p.name), key=lambda p: p.name)


def stop(process):
    if process is not None:
        if process.poll() is None:
            try:
                process.terminate()
            except ProcessLookupError:
                pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try:
                process.kill()
            except ProcessLookupError:
                pass
            process.wait()


def probe(path, content, timeout):
    started = time.monotonic()
    sample = {"file": path.name, "valid": False}
    process = None
    try:
        config = json.loads(content)
        outbounds = config["outbounds"]
        outbound = next((o for o in outbounds if o.get("tag") == "proxy"), outbounds[0])
        # Ask the kernel for a free port; fail safely if another process wins the bind race.
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        conf = {"log": {"loglevel": "error"}, "inbounds": [
            {"listen": "127.0.0.1", "port": port, "protocol": "socks",
             "settings": {"auth": "noauth", "udp": False}}], "outbounds": [outbound]}
        with tempfile.TemporaryDirectory(prefix="xray-speed-") as directory:
            filename = Path(directory) / "config.json"
            filename.write_text(json.dumps(conf))
            process = subprocess.Popen(["xray", "-c", str(filename)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            deadline = time.monotonic() + PARAMS["startup_seconds"]
            while True:
                if process.poll() is not None:
                    raise ValueError("Xray exited before probe")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise ValueError("Xray startup timeout")
                    time.sleep(0.05)
            url = os.environ.get("XS_TEST_URL", URL)
            command = ["curl", "-q", "-sS", "-o", os.devnull,
                       "--connect-timeout", str(PARAMS["connect_seconds"]),
                       "--max-time", str(timeout), "--noproxy", "",
                       "--socks5-hostname", f"127.0.0.1:{port}",
                       "-w", "%{http_code} %{speed_download} %{size_download} %{time_total} %{time_starttransfer}"]
            if url.startswith("https://speed.cloudflare.com/"):
                command += ["--referer", "https://speed.cloudflare.com/"]
            curl = None
            try:
                curl = subprocess.Popen(command + ["--url", url], stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, text=True)
                output, _ = curl.communicate(timeout=timeout + 2)
            finally:
                stop(curl)
            http, rate, size, seconds, first = map(float, output.split())
            if not all(math.isfinite(v) for v in (http, rate, size, seconds, first)):
                raise ValueError("non-finite metrics")
            sample.update(http=int(http), curl_status=curl.returncode,
                          bytes_per_second=rate, bytes=size, seconds=seconds,
                          time_starttransfer=first)
            sample["valid"] = (http == 200 and rate > 0 and size > 0 and seconds > 0
                               and (curl.returncode == 0 or
                                    (curl.returncode == 28 and seconds - first >= 1)))
            if not sample["valid"]:
                sample["error"] = "no valid download sample"
    except (ValueError, KeyError, IndexError, TypeError, AttributeError, OSError, subprocess.TimeoutExpired):
        # Do not expose node credentials/configuration through exception text.
        sample["error"] = "invalid configuration, startup failure or malformed probe metrics"
    finally:
        stop(process)
        sample["wall_seconds"] = time.monotonic() - started
    return sample


def valid_cache(value, key):
    try:
        return (value["version"] == 2 and value["key"] == key
                and 0 <= time.time() - value["created_at"] < 600
                and isinstance(value["results"], list) and bool(value["results"])
                and all(isinstance(r["file"], str) and r["valid"] is True
                        and all(isinstance(r[k], (int, float)) and math.isfinite(r[k]) and r[k] > 0
                                for k in ("bytes_per_second", "bytes", "seconds"))
                        for r in value["results"]))
    except (KeyError, TypeError, ValueError):
        return False


def measure(subscriptions, pattern, refresh=False):
    started = time.monotonic()
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", str(
        Path.home() / ".cache"))) / "xray-speed-test"
    cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    # One lock across filters: parallel bandwidth samples cannot be compared reliably.
    with (cache_dir / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        files = nodes(subscriptions, pattern)
        if not files:
            raise ValueError("no matching node configurations")
        # Snapshot once, including content in the cache key; subscription replacement invalidates cache.
        snapshots = [(p, p.read_bytes()) for p in files]
        identity = {"directory": str(subscriptions.resolve()), "filter": pattern,
                    "url": os.environ.get("XS_TEST_URL", URL), "parameters": PARAMS,
                    "files": [(p.name, hashlib.sha256(data).hexdigest()) for p, data in snapshots]}
        key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
        cache = cache_dir / (key + ".json")
        if not refresh:
            try:
                value = json.loads(cache.read_text())
                if valid_cache(value, key):
                    return value | {"cached": True}
            except (OSError, ValueError):
                pass
        samples = []
        for path, data in snapshots:
            print(f"xray-speed-test: quick {path.name}", file=sys.stderr, flush=True)
            samples.append(probe(path, data, PARAMS["quick_seconds"]))
        finalists = sorted((s for s in samples if s["valid"]),
                           key=lambda s: (-s["bytes_per_second"], s["file"]))[:PARAMS["finalists"]]
        contents = {p.name: (p, data) for p, data in snapshots}
        final = []
        for sample in finalists:
            print(f"xray-speed-test: final {sample['file']}", file=sys.stderr, flush=True)
            final.append(probe(*contents[sample["file"]], PARAMS["final_seconds"]))
        results = sorted((s for s in final if s["valid"]),
                         key=lambda s: (-s["bytes_per_second"], s["file"]))
        value = {"version": 2, "key": key, "filter": pattern, "url": identity["url"],
                 "parameters": PARAMS, "created_at": time.time(), "cached": False,
                 "quick": samples, "final": final, "results": results,
                 "wall_seconds": time.monotonic() - started}
        if results:
            publish(cache, value)
        return value


def request(queue, subscriptions, pattern, refresh):
    for name in ("requests", "processing", "results"):
        if not (queue / name).is_dir():
            raise ValueError("speed-test worker is not deployed")
    token = uuid.uuid4().hex
    target = queue / "results" / (token + ".json")
    publish(queue / "requests" / (token + ".json"),
            {"id": token, "filter": pattern, "refresh": refresh}, staging=queue)
    count = len(nodes(subscriptions, pattern))
    budget = (PARAMS["startup_seconds"] + PARAMS["quick_seconds"] + 4) * count + 60
    deadline = time.monotonic() + budget
    next_report = 0
    try:
        while time.monotonic() < deadline:
            if target.is_file():
                value = json.loads(target.read_text())
                if value.get("id") != token:
                    raise ValueError("worker result ID mismatch")
                if value.get("error"):
                    raise ValueError(value["error"])
                return value["measurement"]
            if time.monotonic() >= next_report:
                print(f"xray-speed-test: waiting for worker ({token})", file=sys.stderr, flush=True)
                next_report = time.monotonic() + 10
            time.sleep(0.2)
        raise ValueError("worker wait timed out; no switch performed")
    finally:
        (queue / "requests" / (token + ".json")).unlink(missing_ok=True)
        target.unlink(missing_ok=True)


def worker(queue, subscriptions):
    with (queue / "worker.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Recover work claimed before a service interruption.
        for path in (queue / "processing").glob("*.json"):
            path.rename(queue / "requests" / path.name)
        while True:
            pending = sorted((queue / "requests").glob("*.json"))
            if not pending:
                break
            for source in pending:
                token = source.stem
                if len(token) != 32 or any(c not in "0123456789abcdef" for c in token):
                    source.unlink()
                    continue
                claimed = queue / "processing" / source.name
                try:
                    source.rename(claimed)
                except FileNotFoundError:
                    continue
                try:
                    value = json.loads(claimed.read_text())
                    if (value.get("id") != token or not isinstance(value.get("filter"), str)
                            or type(value.get("refresh")) is not bool
                            or set(value) != {"id", "filter", "refresh"}):
                        raise ValueError("invalid worker request")
                    result = {"id": token, "measurement": measure(
                        subscriptions, value["filter"], value["refresh"])}
                except (OSError, ValueError, TypeError, AttributeError):
                    result = {"id": token, "error": "speed-test worker request failed"}
                publish(queue / "results" / source.name, result)
                claimed.unlink()
        # Results abandoned by timed-out clients expire after one day.
        for path in (queue / "results").glob("*.json"):
            if time.time() - path.stat().st_mtime > 86400:
                path.unlink()


def main():
    parser = argparse.ArgumentParser(prog="xray-speed-test", description=__doc__)
    parser.add_argument("filter", nargs="?", default=os.environ.get("XS_FILTER", "Japan"))
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--via-worker", action="store_true")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--queue-dir", type=Path, default=QUEUE)
    args = parser.parse_args()
    xdir = Path(os.environ.get("XRAY_CONF_DIR", str(
        Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "xray")))
    if args.worker:
        # Worker parameters are fixed by the host, never supplied in requests.
        os.environ.pop("XS_TEST_URL", None)
        worker(args.queue_dir, xdir / "subscriptions")
        return 0
    value = (request(args.queue_dir, xdir / "subscriptions", args.filter, args.refresh)
             if args.via_worker else measure(xdir / "subscriptions", args.filter, args.refresh))
    print(json.dumps(value, allow_nan=False))
    return 0 if value["results"] else 1


if __name__ == "__main__":
    def interrupted(signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, ValueError) as error:
        print(f"xray-speed-test: {error}", file=sys.stderr)
        sys.exit(1)
