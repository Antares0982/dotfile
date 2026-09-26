import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time


MOCK = r'''
import json, os, signal, socket, sys, time
from pathlib import Path

root = Path(os.environ["XS_MOCK_DIR"])
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "events").open("a") as stream:
    stream.write(json.dumps([tool, args, os.getpid()]) + "\n")
if tool == "xray":
    config = json.loads(Path(args[1]).read_text())
    sample = config["outbounds"][0]["sample"]
    if sample.get("startup") == "fail":
        sys.exit(1)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    if sample.get("startup") == "hang":
        time.sleep(30)
        sys.exit(1)
    port = config["inbounds"][0]["port"]
    with socket.socket() as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", port))
        server.listen()
        (root / str(port)).write_text(json.dumps(sample))
        while True:
            connection, _ = server.accept()
            connection.close()
elif tool == "curl":
    assert args[0] == "-q"
    assert args[args.index("--noproxy") + 1] == ""
    assert args[args.index("--max-time") + 1] == "10"
    assert args[args.index("--connect-timeout") + 1] == "5"
    if args[args.index("--url") + 1].startswith("https://speed.cloudflare.com/"):
        if "--referer" not in args or args[args.index("--referer") + 1] != "https://speed.cloudflare.com/":
            print("403 0 1 1.3 1.2", end="")
            sys.exit(0)
    else:
        assert "--referer" not in args
    port = args[args.index("--socks5-hostname") + 1].split(":")[1]
    sample = json.loads((root / port).read_text())
    if sample.get("slow"):
        time.sleep(30)
    print(sample.get("metrics", "200 1000000 2000000 2.2 0.2"), end="")
    sys.exit(sample.get("status", 0))
elif tool == "sudo":
    os.execvp(args[0], args)
'''


def check():
    script = Path(__file__).with_name("xs.sh")
    with tempfile.TemporaryDirectory(prefix="xs-check-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        mock = bin_dir / "mock"
        mock.write_text(f"#!{sys.executable}\n" + MOCK)
        mock.chmod(0o755)
        for tool in ("xray", "curl", "systemctl", "sudo"):
            (bin_dir / tool).symlink_to(mock)
        env = dict(os.environ)
        for name in ("XS_FILTER", "XS_TEST_URL", "XS_CONFIG_PATH"):
            env.pop(name, None)
        env.update(
            PATH=f"{bin_dir}:{env['PATH']}",
            XRAY_CONF_DIR=str(root),
            XS_SYSTEMD_SCOPE="user",
            XS_MOCK_DIR=str(root),
        )
        subs = root / "subscriptions"
        cache = root / "speed_test.json"
        active = root / "config.json"
        events = root / "events"

        def run(*args, success=True, overrides=None):
            result = subprocess.run(
                ["bash", str(script), *args],
                env=env | (overrides or {}), capture_output=True, text=True,
                timeout=15,
            )
            assert (result.returncode == 0) == success, result
            assert not list(root.glob(".xs.*"))
            return result

        def node(name, **sample):
            (subs / name).write_text(json.dumps({
                "outbounds": [{"tag": "proxy", "sample": sample}]
            }))

        def calls(tool):
            if not events.exists():
                return []
            return [entry for line in events.read_text().splitlines()
                    if (entry := json.loads(line))[0] == tool]

        def reset():
            cache.unlink(missing_ok=True)
            for path in subs.iterdir():
                path.unlink()

        assert "Usage: xs" in run("--help").stdout
        for args in (("--unknown",), ("one", "two"), ("--help", "extra")):
            assert run(*args, success=False).returncode == 2
        assert not events.exists()
        subs.mkdir()
        node("Japan slow.json")
        node("Japan fast.json", metrics="200 2000000 4000000 2.2 0.2")
        node("Hong.json")
        assert "16.00 Mbps" in run().stdout
        assert active.readlink().name == "Japan fast.json"
        assert len(calls("curl")) == 2
        assert calls("systemctl")[-1][1] == ["--user", "restart", "xray.service"]
        run()
        assert active.readlink().name == "Japan slow.json"
        assert len(calls("curl")) == 2
        run("Hong", overrides={"XS_FILTER": "Japan"})
        assert active.readlink().name == "Hong.json"
        run(overrides={"XS_FILTER": "Hong"})
        assert len(calls("curl")) == 3
        run("", overrides={"XS_FILTER": "absent"})
        assert len(json.loads(cache.read_text())["results"]) == 3
        count = len(calls("curl"))
        run("", overrides={"XS_TEST_URL": "https://example.test/download"})
        assert len(calls("curl")) == count + 3
        assert calls("curl")[-1][1][-1] == "https://example.test/download"
        for content in ("[]", "broken", '{"version":1,"results":null}'):
            cache.write_text(content)
            run()
            assert json.loads(cache.read_text())["version"] == 1
        os.utime(cache, (time.time() - 601,) * 2)
        count = len(calls("curl"))
        run()
        assert len(calls("curl")) == count + 2
        (subs / "Japan fast.json").unlink()
        run()
        assert active.readlink().name == "Japan slow.json"

        reset()
        node("[JP]*?.json")
        node("JPP.json")
        node("-Japan.json")
        node("Japan\nnewline.json")
        run("[JP]*?")
        assert active.readlink().name == "[JP]*?.json"
        run("--", "-Japan")
        assert active.readlink().name == "-Japan.json"
        run("newline")
        run("newline")
        assert active.readlink().name == "Japan\nnewline.json"
        run("japan", success=False)

        reset()
        node("Japan timeout.json", status=28)
        node("Japan short.json", status=28, metrics="200 1000000 1 0.5 0.2")
        node("Japan empty.json", metrics="200 0 0 2 0.1")
        node("Japan http.json", metrics="503 1000000 100 2 0.1")
        node("Japan forbidden.json", metrics="403 0 1 1.3 1.2")
        node("Japan broken.json", status=56)
        result = run()
        assert "HTTP 403, bytes 1, curl 0" in result.stderr
        assert [r["file"] for r in json.loads(cache.read_text())["results"]] == [
            "Japan timeout.json"
        ]
        for line in events.read_text().splitlines():
            tool, _, pid = json.loads(line)
            if tool in ("xray", "curl"):
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f"leaked {tool}: {pid}")

        reset()
        node("Japan fail.json", startup="fail")
        node("Japan hang.json", startup="hang")
        count = len(calls("systemctl"))
        previous = active.readlink()
        run(success=False)
        assert active.readlink() == previous
        assert len(calls("systemctl")) == count
        assert not cache.exists()

        reset()
        (subs / "Japan invalid.json").write_text("{}")
        run(success=False)
        reset()
        node("Japan.json")
        count = len(calls("xray"))
        with socket.socket() as server:
            server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server.bind(("127.0.0.1", 24100))
            server.listen()
            run(success=False)
        assert len(calls("xray")) == count
        run(overrides={"XS_SYSTEMD_SCOPE": "system",
                       "XS_CONFIG_PATH": str(subs / "active.json")})
        assert (subs / "active.json").readlink().name == "Japan.json"
        assert calls("sudo")[-1][1] == ["systemctl", "restart", "xray.service"]
        assert calls("systemctl")[-1][1] == ["restart", "xray.service"]

        for sig in (signal.SIGTERM, signal.SIGINT):
            reset()
            node("Japan.json", slow=True)
            count = len(calls("curl"))
            with subprocess.Popen(
                ["bash", str(script)], env=env, start_new_session=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            ) as process:
                deadline = time.monotonic() + 5
                while len(calls("curl")) == count and time.monotonic() < deadline:
                    time.sleep(0.05)
                assert len(calls("curl")) == count + 1
                process.send_signal(sig)
                process.communicate(timeout=5)
                assert process.returncode == 128 + sig
            assert not list(root.glob(".xs.*"))
            assert not cache.exists()
            for tool in ("xray", "curl"):
                try:
                    os.kill(calls(tool)[-1][2], 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f"leaked {tool} after interrupt")
        print("xs regression checks passed")


if __name__ == "__main__":
    check()
