"""Check private state, firewall and privileges."""

import importlib.util
import json
import os
import socket
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check():
    prepare = load("mihomo-prepare")
    daemon = load("mihomo-darwin")
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        user = SimpleNamespace(
            pw_uid=os.getuid(), pw_gid=os.getgid(), pw_dir=directory, pw_name="antares"
        )
        subscription = root / "subscription"
        subscription.write_text("https://example.invalid/subscription")
        template = root / "template.json"
        template.write_text(
            json.dumps(
                {
                    "proxy-providers": {"subscription": {}},
                    "mixed-port": 1081,
                    "listeners": [],
                }
            )
        )
        state = root / "Library/Application Support/mihomo"
        with (
            patch.object(prepare.sys, "platform", "darwin"),
            patch.object(prepare.Path, "home", return_value=root),
            patch.object(prepare.pwd, "getpwnam", return_value=user),
            patch.object(prepare.os, "geteuid", return_value=501),
        ):
            prepare.prepare(template, subscription)
            first = (state / "secret").read_text()
            prepare.prepare(template, subscription)
            assert (state / "secret").read_text() == first
            assert (
                json.loads((state / "client/connection.json").read_text())["secret"]
                == first
            )
            for path in (
                state / "config.json",
                state / "secret",
                state / "client/connection.json",
                state / "speed-test.lock",
            ):
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
        response = SimpleNamespace(
            stdout='anchor "com.apple/*" all', stderr="Token : 17\n"
        )
        with (
            patch.object(daemon, "TOKEN", token),
            patch.object(daemon, "run", return_value=response) as run,
        ):
            daemon.enable_pf("rules")
            assert token.read_text() == "17"
            daemon.disable_pf()
            assert not token.exists()
            assert (daemon.PF, "-X", "17") in [call.args for call in run.call_args_list]
            assert [call.args for call in run.call_args_list if "-F" in call.args] == [
                (daemon.PF, "-a", daemon.ANCHOR, "-F", "rules")
            ]

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
        settings = {
            "mixed-port": 1081,
            "allow-lan": True,
            "tun": {"enable": True},
            "listeners": [
                {"name": "global", "port": 1082},
                {"name": "direct", "port": 1083},
                {"name": "bandwidth-test", "port": 17901},
            ],
        }
        away = daemon.pf_rules(settings, 397)
        home = daemon.pf_rules(settings, 397, "en0", True, "utun4")
        assert "block drop out quick all" in away and "pass in quick on en0" not in away
        assert "user 397" in home and "on utun4" in home and "port 17901" not in home
        assert "from 192.168.0.0/24" in home and "1083, 17900" in home
        assert home.index("port 53 user 397") < home.index("block drop out quick")
        settings["bind-address"] = "0.0.0.0"
        settings["external-controller"] = "0.0.0.0:17900"
        for listener in settings["listeners"]:
            listener.update(listen="127.0.0.1", udp=False)
        template.write_text(json.dumps(settings))
        worker = SimpleNamespace(pw_uid=397, pw_gid=493)
        protected = root / "protected"
        protected.mkdir()
        (protected / "data").mkdir()
        tunnel = Mock()
        tunnel.fileno.return_value = 19
        child = Mock()
        child.poll.return_value = 1
        with (
            patch.object(daemon, "STATE", protected),
            patch.object(daemon.pwd, "getpwnam", side_effect=[user, worker]),
            patch.object(
                daemon, "physical_uplink", return_value=("en0", "192.168.0.1")
            ),
            patch.object(daemon, "is_home", return_value=False),
            patch.object(daemon, "protect") as guard,
            patch.object(daemon, "disable_pf") as disable,
            patch.object(daemon, "wait_ports"),
            patch.object(daemon, "set_dns"),
            patch.object(daemon, "open_tunnel", return_value=(tunnel, "utun4")),
            patch.object(daemon.os, "chown"),
            patch.object(
                daemon, "run", return_value=SimpleNamespace(stdout=json.dumps(settings))
            ),
            patch.object(
                daemon.subprocess, "Popen", side_effect=[child, Mock()]
            ) as spawn,
        ):
            try:
                daemon.start(template, subscription, "prepare", "core", "ctl")
            except ValueError as error:
                assert "Mihomo exited" in str(error)
            else:
                raise AssertionError("Core failure ignored")
            args = spawn.call_args_list[0].kwargs
            assert args["user"] == worker.pw_uid and args["pass_fds"] == (19,)
            assert args["group"] == worker.pw_gid
            assert guard.call_args_list[-1].args == (settings, worker.pw_uid)
            disable.assert_not_called()
            tunnel.close.assert_called_once()
        assert (
            json.loads((protected / "config.json").read_text())["tun"][
                "file-descriptor"
            ]
            == 19
        )
    print("PASS: private preparation, PF gating, unprivileged core and failure cleanup")


if __name__ == "__main__":
    check()
