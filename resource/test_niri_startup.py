import importlib.util
import tempfile
from pathlib import Path
from unittest.mock import patch


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


layout = load("niri-startup")
qbit = load("qbittorrent-startup")


def window(app, number):
    return {"id": number, "app_id": app, "title": app, "is_floating": False}


def simulate(snapshots, timeout=1):
    calls = []
    index = 0
    clock = 0

    def msg(*args):
        nonlocal index
        if args == ("windows",):
            result = snapshots[min(index, len(snapshots) - 1)]
            index += 1
            return result
        calls.append(args)

    def now():
        nonlocal clock
        clock += 0.1
        return clock

    with (
        patch.object(layout, "msg", msg),
        patch.object(layout.time, "monotonic", now),
        patch.object(layout.time, "sleep"),
    ):
        layout.arrange(timeout)
    return calls


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        assert layout.claim_session(root, "socket-1")
        assert not layout.claim_session(root, "socket-1")
        assert layout.claim_session(root, "socket-2")

        original = (
            "[GUI]\nStartUpWindowState=Normal\nQt6\\State=@ByteArray(\\0\\xff)\n\n"
            "[Preferences]\nGeneral\\SystrayEnabled=false\nOther=100%\n\n"
            "[BitTorrent]\nSession\\SavePath=/keep/me\n"
        )
        path = root / "qBittorrent.conf"
        path.write_text(original)
        qbit.save_config(path)
        updated = path.read_text()
        assert updated == original.replace("=Normal", "=Hidden").replace(
            "Enabled=false", "Enabled=true"
        )
        assert path.with_suffix(".conf.before-niri").read_text() == original
        qbit.save_config(path)
        assert path.read_text() == updated
        assert path.with_suffix(".conf.before-niri").read_text() == original
        for text in (
            "",
            "[GUI]",
            "[Preferences]",
            "[GUI]\nOther=unchanged\n",
            "[Preferences]\nOther=unchanged\n",
            "[GUI]\nOther=unchanged\n\n[Preferences]\nOther=unchanged\n\n[BitTorrent]\nOther=unchanged\n",
        ):
            updated = qbit.configure(text)
            assert "StartUpWindowState=Hidden" in updated
            assert "General\\SystrayEnabled=true" in updated
            assert qbit.configure(updated) == updated
            parsed = qbit.configparser.ConfigParser(interpolation=None)
            parsed.read_string(updated)
            assert parsed["GUI"]["StartUpWindowState"] == "Hidden"
            assert parsed["Preferences"]["General\\SystrayEnabled"] == "true"
            if "Other" in text:
                assert "Other=unchanged" in updated
        path.write_text("broken configuration")
        try:
            qbit.save_config(path)
        except qbit.configparser.Error:
            pass
        else:
            raise AssertionError("Invalid configuration was overwritten")
        assert path.read_text() == "broken configuration"

    apps = (*layout.TERMINALS, "google-chrome", "QQ", "org.telegram.desktop")
    windows = [window(app, number) for number, app in enumerate(apps, 1)]
    calls = simulate([[windows[3]], [windows[3]], windows])
    assert sum(call[:2] == ("action", "spawn") for call in calls) == 5
    assert calls.count(("action", "consume-or-expel-window-left", "--id", 3)) == 1
    assert ("action", "reset-window-height", "--id", 2) in calls
    assert ("action", "reset-window-height", "--id", 3) in calls
    assert ("action", "set-column-width", "100%") in calls
    assert calls.count(("action", "expand-column-to-available-width")) == 1
    assert calls[-1] == ("action", "focus-window", "--id", 1)

    calls = simulate([[], windows[3:]])
    assert ("action", "set-column-width", "100%") in calls
    assert ("action", "expand-column-to-available-width") in calls
    assert not any(call[1] == "consume-or-expel-window-left" for call in calls)

    login = window("QQ", 10) | {"title": "QQ Login"}
    calls = simulate([[], [login, windows[5]]])
    assert not any(call[1] == "expand-column-to-available-width" for call in calls)

    with (
        patch.object(qbit, "running", return_value=True),
        patch.object(qbit, "save_config") as save,
        patch.object(qbit.os, "execl") as execute,
    ):
        qbit.main()
        save.assert_not_called()
        execute.assert_not_called()
    print("Startup checks passed")


if __name__ == "__main__":
    main()
