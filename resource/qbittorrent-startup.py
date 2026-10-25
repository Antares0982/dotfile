import configparser
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def running():
    for process in Path("/proc").glob("[0-9]*"):
        try:
            if process.stat().st_uid == os.getuid() and (
                process / "exe"
            ).readlink().name in {"qbittorrent", ".qbittorrent-wrapped"}:
                return True
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
    return False


def tray_ready():
    result = subprocess.run(
        [
            "@gdbus@",
            "call",
            "--session",
            "--dest",
            "org.kde.StatusNotifierWatcher",
            "--object-path",
            "/StatusNotifierWatcher",
            "--method",
            "org.freedesktop.DBus.Properties.Get",
            "org.kde.StatusNotifierWatcher",
            "IsStatusNotifierHostRegistered",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=5,
    )
    return result.returncode == 0 and "<true>" in result.stdout


def configure(text):
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read_string(text)
    for section, key, value in (
        ("GUI", "StartUpWindowState", "Hidden"),
        ("Preferences", "General\\SystrayEnabled", "true"),
    ):
        pattern = rf"(?ms)^\[{section}\][^\S\n]*(?:\n|\Z).*?(?=^\[|\Z)"
        match = re.search(pattern, text)
        if match is None:
            text = text.rstrip("\n") + f"\n\n[{section}]\n{key}={value}\n"
            continue
        block = match.group()
        setting = rf"(?m)^{re.escape(key)}\s*=.*$"
        if re.search(setting, block):
            block = re.sub(
                setting, lambda _, replacement=f"{key}={value}": replacement, block
            )
        else:
            block = block.rstrip("\n") + f"\n{key}={value}\n\n"
        text = text[: match.start()] + block + text[match.end() :]
    return text


def save_config(path):
    text = path.read_text() if path.exists() else ""
    updated = configure(text)
    if text == updated:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    backup = path.with_suffix(".conf.before-niri")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temp:
        try:
            temp.write(updated)
            temp.flush()
            os.fsync(temp.fileno())
            os.replace(temp.name, path)
        finally:
            Path(temp.name).unlink(missing_ok=True)


def main():
    if running():
        return
    deadline = time.monotonic() + 30
    while not tray_ready():
        if time.monotonic() >= deadline:
            raise TimeoutError("Waybar tray did not become ready")
        time.sleep(0.2)
    if running():
        return
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    save_config(config_home / "qBittorrent/qBittorrent.conf")
    os.execl("@qbittorrent@", "qbittorrent", "--no-splash")


if __name__ == "__main__":
    main()
