"""Check isolation, ranking, cache invalidation and agent input boundaries."""

import importlib.util
import io
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mihomo", Path(__file__).with_name("mihomo-tools.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def check_service_home():
    with patch("sys.platform", "linux"), patch.object(Path, "home", side_effect=RuntimeError("No home")):
        service = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(service)
        assert service.CLIENT == Path("/run/mihomo-client/connection.json")
        assert service.LOCK == Path("/run/lock/mihomo-speed-test.lock")
        with patch.object(service, "request", side_effect=[
            {"proxies": {"JP": {"all": ["Japan 1"]}}},
            {"providers": {"cn": {"ruleCount": 1}}},
            {"providers": {"cn": {"ruleCount": 1}}},
        ]):
            service.ready()
    with patch("sys.platform", "darwin"), patch.object(Path, "home", return_value=Path("/Users/tester")):
        darwin = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(darwin)
        assert darwin.CLIENT == Path("/Users/tester/Library/Application Support/mihomo/client/connection.json")
        assert darwin.LOCK == Path("/Users/tester/Library/Application Support/mihomo/speed-test.lock")


def check():
    check_service_home()
    token = "a" * 32
    for action in ("status", "update", "restart"):
        assert m.valid_request({"id": token, "action": action}, token)
    assert m.valid_request({"id": token, "action": "select", "group": "JP", "node": "Japan 1"}, token)
    for value in (None, [], {"action": []}, {"id": token, "action": "restart", "command": "sh"},
                  {"id": token, "action": "speed", "group": "SG", "refresh": False},
                  {"id": token, "action": "speed", "group": "JP", "refresh": 1}):
        assert not m.valid_request(value, token)
    state = {"JP": "Japan 1", "SG": "Singapore 1", "BENCH": "Japan 2"}
    members = ["Japan 1", "Japan 2", "Japan 3", "Japan 4"]
    updates = ["initial"]
    calls = []

    def request(path, method="GET", data=None):
        if path == "/providers/proxies/subscription":
            return {"updatedAt": updates[-1]}
        name = path.rsplit("/", 1)[-1]
        if method == "PUT":
            assert name == "BENCH"
            state[name] = data["name"]
        return {"now": state[name], "all": members}

    def sample(node, seconds):
        m.select("BENCH", node)
        calls.append((node, seconds))
        return {"node": node, "valid": not (node == "Japan 4" and seconds == 5),
                "bytes_per_second": int(node[-1]) * 1000000}

    with tempfile.TemporaryDirectory() as directory:
        lock = Path(directory) / "lock"
        lock.touch()
        real_open = open

        def open_lock(path, *args, **kwargs):
            return real_open(lock if path == m.LOCK else path, *args, **kwargs)

        with patch.dict(os.environ, {"XDG_CACHE_HOME": directory}), patch.object(m, "request", request), \
             patch.object(m, "sample", sample), patch("builtins.open", open_lock), patch("sys.stderr", io.StringIO()):
            result = m.measure("JP")
            assert [v["node"] for v in result["results"]] == ["Japan 3", "Japan 2"]
            assert len(calls) == 7
            assert m.measure("JP")["cached"] and len(calls) == 7
            updates.append("new subscription")
            assert not m.measure("JP")["cached"] and len(calls) == 14
            with patch.object(m, "sample", side_effect=KeyboardInterrupt):
                try:
                    m.measure("JP", refresh=True)
                except KeyboardInterrupt:
                    pass
            assert state == {"JP": "Japan 1", "SG": "Singapore 1", "BENCH": "Japan 2"}
            try:
                m.select("JP", "DIRECT")
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid region selection accepted")
            def choose(name, node):
                state[name] = node
                return {"group": name, "node": node}
            with patch.object(m, "select", choose), patch.object(m, "connection", return_value={"test_port": 17901}), \
                 patch.object(m.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="ip=1.2.3.4\nloc=SG\n")) as run:
                try:
                    m.execute({"action": "select", "group": "JP", "node": "Japan 2"})
                except ValueError:
                    pass
                else:
                    raise AssertionError("Wrong egress accepted")
                assert state["JP"] == "Japan 1"
                assert state["BENCH"] == "Japan 2"
                assert "http://127.0.0.1:17901" in run.call_args.args[0]
                run.return_value = SimpleNamespace(returncode=0, stdout="ip=1.2.3.4\nloc=JP\n")
                result = m.execute({"action": "select", "group": "JP", "node": "Japan 3"})
                assert result["country"] == "JP" and state["JP"] == "Japan 3"
                assert state["BENCH"] == "Japan 2" and state["SG"] == "Singapore 1"
    print("PASS: home-less service readiness, Darwin paths, requests, bandwidth ranking, cache and selection isolation")


if __name__ == "__main__":
    check()
