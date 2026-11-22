import json
import subprocess
import tempfile
import time
from pathlib import Path
from unittest.mock import Mock, patch

from napcat_login_qr import forward


def test_forward():
    now = time.monotonic_ns() // 1000
    first = "https://txz.qq.com/p?k=first%2Bkey&f=1"
    second = "https://txz.qq.com/p?k=second&f=1"
    endpoint = "https://api.telegram.org/botDUMMY/sendPhoto"

    def event(message, stamp):
        return json.dumps({"MESSAGE": message, "__MONOTONIC_TIMESTAMP": str(stamp)})

    events = [
        event("普通消息", now),
        event("二维码解码URL: https://example.org/p?k=test&f=1", now),
        event("二维码解码URL: https://txz.qq.com/p?f=1", now),
        event("二维码解码URL: " + second, now - 121_000_000),
        event("二维码解码URL: " + first, now),
        event("二维码解码URL: " + first, now + 1),
        event("二维码解码URL: " + second, now + 2),
    ]
    success = Mock(status_code=200)
    success.json.return_value = {"ok": True}
    with (
        tempfile.TemporaryDirectory() as directory,
        patch("napcat_login_qr.requests.post") as post,
        patch("napcat_login_qr.time.sleep") as sleep,
    ):
        post.side_effect = [Mock(status_code=503), success, success]
        checkpoint = Path(directory) / "last-sent"
        forward(events, checkpoint, endpoint, 123)
        forward(events, checkpoint, endpoint, 123)
        sleep.assert_called_once()
        assert post.call_count == 3
        for call, url in zip(post.call_args_list, [first, first, second], strict=True):
            assert call.args == (endpoint,) and call.kwargs["data"]["chat_id"] == 123
            name, image, mime = call.kwargs["files"]["photo"]
            assert name.endswith(".png") and mime == "image/png"
            decoded = subprocess.check_output(["zbarimg", "-q", "--raw", "-"], input=image)
            assert decoded.rstrip(b"\n") == url.encode()


if __name__ == "__main__":
    test_forward()
    print("NapCat QR forwarding checks passed")
