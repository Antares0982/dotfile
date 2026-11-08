"""Check startup housekeeping in a temporary home."""

import os
from pathlib import Path
import subprocess
import tempfile


def check():
    with tempfile.TemporaryDirectory() as directory:
        home = Path(directory)
        chrome = home / ".config/google-chrome"
        chrome.mkdir(parents=True)
        (chrome / "Preferences").write_text("current")
        copy = home / ".config/google-chrome-no-proxy"
        copy.mkdir()
        (copy / "stale").touch()
        downloads = home / "Downloads"
        downloads.mkdir()
        (downloads / "old file.torrent").touch()
        (downloads / "keep.txt").touch()
        pull = home / "pull-all"
        pull.write_text('#!/bin/sh\ntouch "$HOME/pulled"\n')
        pull.chmod(0o700)
        env = {**os.environ, "HOME": str(home), "PULL_ALL": str(pull)}
        subprocess.run(["bash", str(Path(__file__).with_name("nix-autostart.sh"))], env=env, check=True)
        assert (home / "pulled").exists()
        assert (copy / "Preferences").read_text() == "current"
        assert not (copy / "stale").exists()
        assert sorted(p.name for p in downloads.iterdir()) == ["keep.txt"]
    print("PASS: repository update and desktop housekeeping")


if __name__ == "__main__":
    check()
