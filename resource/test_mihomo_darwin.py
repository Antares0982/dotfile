"""Check private state, firewall and privileges."""

import importlib.util
import json
import os
import socket
from pathlib import Path
import tempfile
from types import SimpleNamespace
from unittest.mock import Mock, patch


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check():
    prepare = load("mihomo-prepare")
    daemon = load("mihomo-darwin")
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        user = SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid(), pw_dir=directory, pw_name="antares")
        subscription = root / "subscription"
        subscription.write_text("https://example.invalid/subscription")
        template = root / "template.json"
        template.write_text(json.dumps({"proxy-providers": {"subscription": {}}, "mixed-port": 1081, "listeners": []}))
        state = root / "Library/Application Support/mihomo"
        with patch.object(prepare.sys, "platform", "darwin"), patch.object(prepare.Path, "home", return_value=root), \
             patch.object(prepare.pwd, "getpwnam", return_value=user), patch.object(prepare.os, "geteuid", return_value=501):
            prepare.prepare(template, subscription)
            first = (state / "secret").read_text()
            prepare.prepare(template, subscription)
            assert (state / "secret").read_text() == first
            assert json.loads((state / "client/connection.json").read_text())["secret"] == first
            for path in (state / "config.json", state / "secret", state / "client/connection.json", state / "speed-test.lock"):
                assert path.stat().st_mode & 0o777 == 0o600
            assert state.stat().st_mode & 0o777 == 0o700
            before = (state / "config.json").read_bytes()
            subscription.write_text("http://example.invalid/not-https")
            try:
                prepare.prepare(template, subscription)
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid subscription accepted")
            assert (state / "config.json").read_bytes() == before

        token = root / "pf-token"
        response = SimpleNamespace(stdout='anchor "com.apple/*" all', stderr="Token : 17\n")
        with patch.object(daemon, "TOKEN", token), patch.object(daemon, "run", return_value=response) as run:
            daemon.enable_pf("rules")
            assert token.read_text() == "17"
            daemon.disable_pf()
            assert not token.exists()
            assert (daemon.PF, "-X", "17") in [call.args for call in run.call_args_list]
            assert [call.args for call in run.call_args_list if "-F" in call.args] == [
                (daemon.PF, "-a", daemon.ANCHOR, "-F", "rules")]

        events = []
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", 0))
            occupied.listen()
            ports = [("127.0.0.1", occupied.getsockname()[1], socket.SOCK_STREAM)]
            with patch.object(daemon.time, "monotonic", side_effect=[0, 121]):
                try:
                    daemon.wait_ports(ports)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Occupied port accepted")
        daemon.wait_ports(ports)
        child = Mock()
        child.poll.return_value = None
        child.wait.return_value = 0

        def run(*args, **kwargs):
            events.append(args)
            if args[0] == "ctl":
                assert kwargs["user"] == user.pw_uid and kwargs["extra_groups"] == []
                raise ValueError("Bootstrap failure")

        def spawn(*args, **kwargs):
            assert events[-1] == (daemon.FIREWALL, "--unblockapp", "core")
            assert kwargs["user"] == user.pw_uid and kwargs["group"] == user.pw_gid
            return child

        with patch.object(daemon.pwd, "getpwnam", return_value=user), patch.object(daemon, "run", run), \
             patch.object(daemon, "wait_ports") as wait_ports, \
             patch.object(daemon, "enable_pf") as enable, patch.object(daemon, "disable_pf") as disable, \
             patch.object(daemon.subprocess, "Popen", spawn):
            try:
                daemon.start(str(template), str(subscription), "prepare", "core", "ctl", "rules")
            except ValueError:
                pass
            else:
                raise AssertionError("Bootstrap failure ignored")
            enable.assert_called_once_with("rules")
            wait_ports.assert_called_once()
            disable.assert_called_once_with()
            child.terminate.assert_called_once_with()
            assert events[-1] == (daemon.FIREWALL, "--remove", "core")

        with patch.object(daemon.pwd, "getpwnam", return_value=user), patch.object(daemon, "run", run), \
             patch.object(daemon, "wait_ports"), \
             patch.object(daemon, "enable_pf", side_effect=ValueError("PF unavailable")), \
             patch.object(daemon, "disable_pf"), patch.object(daemon.subprocess, "Popen") as spawn:
            try:
                daemon.start(str(template), str(subscription), "prepare", "core", "ctl", "rules")
            except ValueError:
                pass
            spawn.assert_not_called()
    print("PASS: private preparation, PF gating, unprivileged core and failure cleanup")


if __name__ == "__main__":
    check()
