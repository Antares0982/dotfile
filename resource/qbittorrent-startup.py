import configparser
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
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


TRAY = {
    "GUI": {"StartUpWindowState": "Hidden"},
    "Preferences": {r"General\SystrayEnabled": "true"},
}


def proxy_settings(port):
    return {
        "Network": {
            r"Proxy\Type": "SOCKS5",
            r"Proxy\IP": "127.0.0.1",
            r"Proxy\Port": str(port),
            r"Proxy\AuthEnabled": "false",
            r"Proxy\HostnameLookupEnabled": "true",
            r"Proxy\Profiles\BitTorrent": "true",
            r"Proxy\Profiles\Misc": "false",
            r"Proxy\Profiles\RSS": "false",
        },
        "BitTorrent": {r"Session\ProxyPeerConnections": "true"},
    }


def parse_config(text):
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read_string(text)
    return parser


def configure(text, settings=TRAY):
    parse_config(text)
    for section, entries in settings.items():
        pattern = rf"(?ms)^\[{section}\][^\S\n]*(?:\n|\Z).*?(?=^\[|\Z)"
        match = re.search(pattern, text)
        block = match.group() if match else f"[{section}]\n"
        for key, value in entries.items():
            setting = rf"(?m)^{re.escape(key)}[ \t]*=.*$"
            if value is None:
                block = re.sub(setting + r"\n?", "", block)
            elif re.search(setting, block):
                block = re.sub(setting, lambda _: f"{key}={value}", block)
            else:
                block = block.rstrip("\n") + f"\n{key}={value}\n\n"
        if match:
            text = text[: match.start()] + block + text[match.end() :]
        else:
            text = text.rstrip("\n") + "\n\n" + block.rstrip("\n") + "\n"
    return text


def write_atomic(path, text):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temp:
        try:
            temp.write(text)
            temp.flush()
            os.fsync(temp.fileno())
            os.replace(temp.name, path)
        finally:
            Path(temp.name).unlink(missing_ok=True)


def save_config(path, port=0, restore_only=False):
    state = path.with_suffix(".mihomo-proxy.json")
    if restore_only and not state.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    lock = os.open(path.parent, os.O_RDONLY)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX)
        text = path.read_text() if path.exists() else ""
        settings = {} if restore_only else TRAY.copy()
        if port:
            proxy = proxy_settings(port)
            if not state.exists():
                old = parse_config(text)
                previous = {
                    section: {
                        key: old.get(section, key, fallback=None) for key in entries
                    }
                    for section, entries in proxy.items()
                }
                write_atomic(state, json.dumps(previous))
            settings.update(proxy)
        elif state.exists():
            settings.update(json.loads(state.read_text()))
        updated = configure(text, settings)
        if text != updated:
            backup = path.with_suffix(".conf.before-niri")
            if path.exists() and not backup.exists():
                shutil.copy2(path, backup)
            write_atomic(path, updated)
        if not port:
            state.unlink(missing_ok=True)
    finally:
        os.close(lock)


def main():
    if running():
        return
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    path = config_home / "qBittorrent/qBittorrent.conf"
    port = int(os.environ.get("QBIT_DIRECT_PORT", 0))
    if sys.argv[1:] == ["--set-proxy"]:
        save_config(path, port)
        return
    if sys.argv[1:] == ["--restore-proxy"]:
        save_config(path, restore_only=True)
        return
    deadline = time.monotonic() + 30
    while not tray_ready():
        if time.monotonic() >= deadline:
            raise TimeoutError("Waybar tray did not become ready")
        time.sleep(0.2)
    if running():
        return
    save_config(path, port)
    os.execl("@qbittorrent@", "qbittorrent", "--no-splash")


if __name__ == "__main__":
    main()
