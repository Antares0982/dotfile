#!@python@

import os
import subprocess
import sys
import time
import urllib
import urllib.parse
from typing import Any

from pydotool import (
    KEY_C,
    KEY_LEFT,
    KEY_LEFTCTRL,
    KEY_RIGHT,
    init,
    input_key_sequence,
    key_combination,
)


def main0(old_clipboard_content: str):
    init()
    time.sleep(0.5)
    key_combination([KEY_LEFTCTRL, KEY_C])
    time.sleep(0.1)
    path = subprocess.check_output(
        "/run/current-system/sw/bin/qdbus org.kde.klipper /klipper org.kde.klipper.klipper.getClipboardContents",
        shell=True,
        encoding="utf-8",
    )
    prefix = "file://"
    if not path.startswith(prefix):
        raise RuntimeError("Clipboard does not contain a file path")

    path = urllib.parse.unquote(path[len(prefix) :]).strip()
    if not os.path.exists(path):
        raise RuntimeError(f"clipboard content path does not exist: {path}")
    script_abs_path = os.path.abspath("@_switch_sh@")
    try:
        subprocess.run(
            ["/run/current-system/sw/bin/bash", script_abs_path, path],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Call error wit stderr {e.stderr} stdout {e.stdout}")

    if old_clipboard_content is not None:
        import shlex

        subprocess.run(
            shlex.split(
                "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.setClipboardContents"
            )
            + [old_clipboard_content]
        )


def main():
    try:
        old_clipboard_content: Any = subprocess.check_output(
            "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.getClipboardContents",
            shell=True,
            encoding="utf-8",
        )
    except Exception:
        old_clipboard_content = None

    try:
        main0(old_clipboard_content)
    except Exception:
        import traceback

        tb = traceback.format_exc()
        try:
            subprocess.run(["notify-send", "Error", tb])
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
