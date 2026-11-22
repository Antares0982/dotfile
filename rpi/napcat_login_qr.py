import hashlib
import io
import json
import logging
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import qrcode
import requests
from qrcode.image.pure import PyPNGImage


QR_LINE = re.compile(r"二维码解码URL: (https://txz\.qq\.com/p\?[!-~]{1,512})")
MAX_AGE = 120


def send_photo(url, expires, endpoint, chat):
    image = io.BytesIO()
    qrcode.make(url, image_factory=PyPNGImage).save(image)
    photo = ("napcat-login.png", image.getvalue(), "image/png")
    for attempt in range(3):
        if time.monotonic() >= expires:
            break
        delay = 2 ** (attempt + 1)
        try:
            response = requests.post(
                endpoint,
                data={"chat_id": chat, "caption": "NapCat 登录二维码"},
                files={"photo": photo},
                timeout=(4, 8),
                allow_redirects=False,
            )
            if response.status_code == 200 and response.json().get("ok") is True:
                logging.info("Login QR sent")
                return True
            logging.warning("Telegram returned HTTP %d", response.status_code)
            if response.status_code == 429:
                delay = response.json().get("parameters", {}).get("retry_after", delay)
            elif response.status_code < 500:
                break
        except requests.RequestException as error:
            logging.warning("Telegram request failed (%s)", type(error).__name__)
        if attempt < 2 and time.monotonic() + delay < expires:
            time.sleep(delay)
        else:
            break
    return False


def forward(lines, checkpoint, endpoint, chat):
    last_stamp, last_digest = 0, ""
    if checkpoint.exists():
        stamp, last_digest = checkpoint.read_text().split()
        last_stamp = int(stamp)

    for line in lines:
        entry = json.loads(line)
        message = entry.get("MESSAGE")
        match = QR_LINE.fullmatch(message) if isinstance(message, str) else None
        if not match:
            continue
        url = match[1]
        query = parse_qs(urlsplit(url).query)
        if not ("k" in query and "f" in query):
            continue
        stamp = int(entry["__MONOTONIC_TIMESTAMP"])
        expires = stamp / 1_000_000 + MAX_AGE
        digest = hashlib.sha256(url.encode("ascii")).hexdigest()
        if stamp < last_stamp or digest == last_digest or time.monotonic() >= expires:
            continue
        if send_photo(url, expires, endpoint, chat):
            temp = checkpoint.with_suffix(".tmp")
            temp.write_text(f"{stamp} {digest}\n")
            temp.replace(checkpoint)
            last_stamp, last_digest = stamp, digest


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    forward(
        sys.stdin,
        Path(os.environ["RUNTIME_DIRECTORY"]) / "last-sent",
        "https://api.telegram.org/bot" + os.environ["ANTARES_MONITOR_TOKEN"] + "/sendPhoto",
        int(os.environ["ANTARES_MONITOR_MYID"]),
    )
