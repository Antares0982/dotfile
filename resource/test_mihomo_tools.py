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


def check():
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
            with patch.object(m, "select", choose), patch.object(m, "connection", return_value={"port": 1081}), \
                 patch.object(m.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="ip=1.2.3.4\nloc=SG\n")):
                try:
                    m.execute({"action": "select", "group": "JP", "node": "Japan 2"})
                except ValueError:
                    pass
                else:
                    raise AssertionError("Wrong egress accepted")
                assert state["JP"] == "Japan 1"
    print("PASS: request validation, bandwidth ranking, cache and selection isolation")


if __name__ == "__main__":
    check()
