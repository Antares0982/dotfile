import fcntl
import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path

TERMINALS = ("kitty-work-left", "kitty-work-top", "kitty-work-bottom")


def msg(*args):
    result = subprocess.run(
        ["@niri@", "msg", "--json", *map(str, args)],
        check=True,
        capture_output=True,
        text=True,
        timeout=5,
    )
    return None if args[0] == "action" else json.loads(result.stdout)


def action(*args):
    return msg("action", *args)


def claim_session(runtime, socket):
    token = hashlib.sha256(socket.encode()).hexdigest()[:16]
    try:
        (runtime / f"niri-layout-{token}").touch(exist_ok=False, mode=0o600)
    except FileExistsError:
        return False
    return True


def place(window, workspace, column):
    action("move-window-to-workspace", "--window-id", window["id"], workspace)
    action("focus-window", "--id", window["id"])
    action("move-column-to-index", column)


def arrange_work(windows, workspace="work", apps=TERMINALS):
    for index, app in enumerate(apps, 1):
        place(windows[app], workspace, index)
        action("set-column-width", "50%")
    action("consume-or-expel-window-left", "--id", windows[apps[2]]["id"])
    for app in apps[1:]:
        action("reset-window-height", "--id", windows[app]["id"])


def open_terminals(timeout=10):
    target = next((w for w in msg("workspaces") if w["is_focused"]), None)
    if target is None or target["output"] is None:
        raise RuntimeError("no focused workspace on a connected monitor")
    token = uuid.uuid4().hex
    apps = tuple(f"kitty-layout-{token}-{side}" for side in ("left", "top", "bottom"))
    for app in apps:
        action(
            "spawn", "--", "@kitty@", "--class", app, "--directory", str(Path.home())
        )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        windows = {w["app_id"]: w for w in msg("windows") if w["app_id"] in apps}
        if len(windows) == 3:
            break
        time.sleep(0.1)
    else:
        raise RuntimeError("timed out waiting for three terminals")

    for app in apps:
        workspace = next(
            (w for w in msg("workspaces") if w["id"] == target["id"]), None
        )
        if workspace is None or workspace["output"] != target["output"]:
            raise RuntimeError("target workspace disappeared or changed monitor")
        window = windows[app]
        action("move-window-to-monitor", "--id", window["id"], target["output"])
        action("focus-window", "--id", window["id"])
        action(
            "move-window-to-workspace", "--window-id", window["id"], workspace["idx"]
        )
        action("move-window-to-tiling", "--id", window["id"])
        current = msg("windows")
        moved = next((w for w in current if w["id"] == window["id"]), None)
        if moved is None or moved["layout"]["pos_in_scrolling_layout"] is None:
            raise RuntimeError("new terminal disappeared or could not be tiled")
        column = moved["layout"]["pos_in_scrolling_layout"][0]
        if any(
            w["id"] != moved["id"]
            and w["workspace_id"] == moved["workspace_id"]
            and not w["is_floating"]
            and w["layout"]["pos_in_scrolling_layout"][0] == column
            for w in current
        ):
            action("consume-or-expel-window-right", "--id", window["id"])
    workspace = next((w for w in msg("workspaces") if w["id"] == target["id"]), None)
    if workspace is None or workspace["output"] != target["output"]:
        raise RuntimeError("target workspace disappeared or changed monitor")
    arrange_work(windows, workspace["idx"], apps)
    action("focus-window", "--id", windows[apps[0]]["id"])


def terminals():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    socket = Path(os.environ["NIRI_SOCKET"]).name
    with (runtime / f"niri-terminals-{socket}.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        open_terminals()


def arrange_im(windows):
    place(windows["QQ"], "im", 1)
    place(windows["org.telegram.desktop"], "im", 2)
    action("set-column-width", "50%")
    action("expand-column-to-available-width")


def arrange_web(windows):
    place(windows["google-chrome"], "web", 1)
    action("set-column-width", "100%")


def arrange(timeout=120):
    commands = {
        **{
            app: ["@kitty@", "--class", app, "--directory", str(Path.home())]
            for app in TERMINALS
        },
        "google-chrome": ["@chrome@"],
        # Preserve the system's Wayland QQ wrapper.
        "QQ": ["/run/current-system/sw/bin/qq"],
        "org.telegram.desktop": ["@telegram@"],
    }
    initial = {w["app_id"] for w in msg("windows")}
    for app, command in commands.items():
        if app not in initial:
            action("spawn", "--", *command)

    pending = {
        "work": (TERMINALS, arrange_work),
        "web": (("google-chrome",), arrange_web),
        "im": (("QQ", "org.telegram.desktop"), arrange_im),
    }
    deadline = time.monotonic() + timeout
    windows = {}
    while pending and time.monotonic() < deadline:
        windows = {}
        for window in sorted(msg("windows"), key=lambda w: w["id"]):
            if window["is_floating"]:
                continue
            if window["app_id"] == "QQ" and window["title"] != "QQ":
                continue
            windows.setdefault(window["app_id"], window)
        for name, (apps, arrange_group) in list(pending.items()):
            if all(app in windows for app in apps):
                try:
                    arrange_group(windows)
                except subprocess.SubprocessError as error:
                    print(f"niri startup: {name}: {error}", file=sys.stderr)
                del pending[name]
        if pending:
            time.sleep(0.1)

    if pending:
        print(f"niri startup: timed out: {', '.join(pending)}", file=sys.stderr)
    action("focus-workspace", "im")
    action("focus-workspace", "work")
    if TERMINALS[0] in windows:
        action("focus-window", "--id", windows[TERMINALS[0]]["id"])


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--terminals"]:
            terminals()
        elif sys.argv[1:]:
            sys.exit("usage: niri-startup.py [--terminals]")
        elif claim_session(
            Path(os.environ["XDG_RUNTIME_DIR"]), os.environ["NIRI_SOCKET"]
        ):
            arrange()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(f"niri layout: {error}")
