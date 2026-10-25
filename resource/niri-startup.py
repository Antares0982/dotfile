import hashlib
import json
import os
import subprocess
import sys
import time
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
    return json.loads(result.stdout)


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


def arrange_work(windows):
    for index, app in enumerate(TERMINALS, 1):
        place(windows[app], "work", index)
        action("set-column-width", "50%")
    action("consume-or-expel-window-left", "--id", windows[TERMINALS[2]]["id"])
    for app in TERMINALS[1:]:
        action("reset-window-height", "--id", windows[app]["id"])


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
    if claim_session(Path(os.environ["XDG_RUNTIME_DIR"]), os.environ["NIRI_SOCKET"]):
        arrange()
