import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch


def check():
    spec = importlib.util.spec_from_file_location(
        "xray_update", Path(__file__).with_name("xray-update.py")
    )
    updater = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(updater)
    nodes = {"Japan A.json": {"outbounds": []}, "Hong Kong.json": {"outbounds": []}}
    failure = ""
    calls = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)

        def run(args, **kwargs):
            nonlocal calls
            calls.append(args)
            status = 0
            if args[0] == "fetch":
                assert not any(k.lower().endswith("_proxy") for k in kwargs["env"])
                folder = Path(kwargs["env"]["XRAY_CONF_DIR"]) / "subscriptions"
                folder.mkdir()
                for name, data in nodes.items():
                    (folder / name).write_text(json.dumps(data))
                status = int(failure == "fetch")
            elif args[0] == "xray":
                data = json.loads(Path(args[-1]).read_text())
                status = int(
                    data.get("invalid", False)
                    or any(entry.get("invalid", False) for entry in data["outbounds"])
                )
            elif args[0] == "xs":
                matches = sorted(
                    p
                    for p in (root / "subscriptions").glob("*.json")
                    if args[1] in p.name
                )
                status = int(not matches or failure == "xs")
                if not status:
                    updater.replace_link(root / "config.json", matches[0])
            else:
                assert args == ["sudo", "systemctl", "restart", "xray.service"]
            if status and kwargs.get("check"):
                raise subprocess.CalledProcessError(status, args)
            return subprocess.CompletedProcess(args, status)

        def update():
            updater.update(
                directory, "/secret/url", "/secret/template", "fetch", "xray", "xs"
            )

        with (
            patch.object(updater.subprocess, "run", side_effect=run),
            patch.dict(
                os.environ, {"http_proxy": "unavailable", "ALL_PROXY": "unavailable"}
            ),
        ):
            update()
            active = root / "config.json"
            assert active.resolve().name == "Japan A.json"
            assert [a for a in calls if a[0] == "xs"] == [["xs", "Japan"]]
            assert (
                sum(a[-1].endswith("/validate.json") for a in calls if a[0] == "xray")
                == 1
            )
            assert not list(root.glob(".generation-*/sub_url.txt"))
            calls.clear()
            nodes["Japan A.json"] = {"outbounds": [], "revision": 2}
            update()
            assert json.loads(active.read_text()) == {"outbounds": [], "revision": 2}
            assert not [a for a in calls if a[0] == "xs"]
            del nodes["Japan A.json"]
            calls.clear()
            update()
            assert active.resolve().name == "Hong Kong.json"
            assert [a for a in calls if a[0] == "xs"] == [["xs", "Japan"], ["xs", ""]]
            for failure, nodes in (
                ("fetch", {"Japan B.json": {"outbounds": []}}),
                ("", {"Japan B.json": {"outbounds": [], "invalid": True}}),
                (
                    "",
                    {
                        "Hong Kong.json": {"outbounds": [{"tag": "proxy"}]},
                        "Japan B.json": {
                            "outbounds": [{"tag": "proxy", "invalid": True}]
                        },
                    },
                ),
                ("", {}),
                ("xs", {"Japan B.json": {"outbounds": []}}),
            ):
                old = active.resolve()
                previous = (root / "subscriptions").resolve()
                try:
                    update()
                except (RuntimeError, subprocess.CalledProcessError):
                    pass
                else:
                    raise AssertionError("invalid update succeeded")
                assert active.resolve() == old and active.exists()
                assert (root / "subscriptions").resolve() == previous
                assert len(list(root.glob(".generation-*"))) == 2
            print("Xray update checks passed")


if __name__ == "__main__":
    check()
