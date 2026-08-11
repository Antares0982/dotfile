"""Smoke-check the relay's new video path with real ffmpeg.

`websockets` isn't in the tri-lug devShell, so it is stubbed; everything under
test (_transcode_video, _fetch_video_bytes, _has_video_segment, the detached
_process_event split) is the relay's own code, unmodified.
"""

import asyncio
import os
import subprocess
import sys
import tempfile
import types

WORK = tempfile.mkdtemp(prefix="relay-video-check-")
os.environ["CACHE_DIR"] = os.path.join(WORK, "cache")
os.environ["VIDEO_WIRE_MAX_BYTES"] = str(512 * 1024)  # force the transcode path
os.environ["VIDEO_FETCH_MAX_BYTES"] = str(50 * 1024 * 1024)

sys.modules["websockets"] = types.ModuleType("websockets")
sys.modules["websockets"].WebSocketClientProtocol = object  # type: ignore[attr-defined]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import qq_napcat_relay as relay  # noqa: E402


def make_video(path, seconds=6, size="1920x1080"):
    subprocess.run(
        [
            "ffmpeg",
            "-nostdin",
            "-v",
            "error",
            "-f",
            "lavfi",
            "-i",
            f"testsrc=size={size}:rate=30:duration={seconds}",
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency=440:duration={seconds}",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-crf",
            "8",
            "-c:a",
            "aac",
            "-pix_fmt",
            "yuv420p",
            "-y",
            path,
        ],
        check=True,
    )
    with open(path, "rb") as fh:
        return fh.read()


def probe(data):
    path = os.path.join(WORK, "probe.mp4")
    with open(path, "wb") as fh:
        fh.write(data)
    out = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type,codec_name,width,height",
            "-of",
            "default=nw=1",
            path,
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return dict(
        line.split("=", 1) for line in out.strip().splitlines() if "=" in line
    ), out


async def main():
    r = relay.Relay()

    # ---- _has_video_segment gates the detached path
    assert relay._has_video_segment({"message": [{"type": "video", "data": {}}]})
    assert not relay._has_video_segment({"message": [{"type": "image", "data": {}}]})
    assert not relay._has_video_segment({"message": "not a list"})
    assert not relay._has_video_segment({})
    print("ok  _has_video_segment")

    # ---- _transcode_video on a real 1080p file
    big = make_video(os.path.join(WORK, "big.mp4"))
    print(f"    source: {len(big)} bytes, 1920x1080, 6s @30fps")
    small = await r._transcode_video(big)
    assert small is not None, "transcode returned None"
    assert len(small) < len(big), (len(small), len(big))
    streams, raw = probe(small)
    assert streams.get("width") == "640", raw
    assert streams.get("height") == "360", raw
    assert "aac" in raw, f"audio track was dropped:\n{raw}"
    assert "h264" in raw, raw
    print(
        f"ok  _transcode_video: {len(big)} -> {len(small)} bytes "
        f"({len(big) / len(small):.1f}x), 640x360, audio kept"
    )

    # ---- garbage in must not raise, must return None
    assert await r._transcode_video(b"not a video at all") is None
    print("ok  _transcode_video degrades on garbage")

    # ---- timeout path kills and reaps the child rather than leaking it
    relay.VIDEO_CONVERT_TIMEOUT = 0.001
    assert await r._transcode_video(big) is None
    relay.VIDEO_CONVERT_TIMEOUT = 180.0
    print("ok  _transcode_video degrades on timeout")

    # ---- _fetch_video_bytes: declared size over the fetch cap => never downloads
    fetched = []

    async def fake_get(url):
        fetched.append(url)
        return big

    r._http_get = fake_get  # type: ignore[assignment]
    over = await r._fetch_video_bytes(
        {"file": "x.mp4", "url": "https://x/x.mp4", "file_size": str(99 * 1024 * 1024)}
    )
    assert over is None and fetched == [], f"downloaded despite the cap: {fetched}"
    print("ok  _fetch_video_bytes refuses an oversized file without downloading")

    # ---- small enough => passed through untouched, no ffmpeg spawned
    tiny = make_video(os.path.join(WORK, "tiny.mp4"), seconds=1, size="320x240")
    assert len(tiny) <= relay.VIDEO_WIRE_MAX_BYTES, len(tiny)

    async def get_tiny(url):
        fetched.append(url)
        return tiny

    r._http_get = get_tiny  # type: ignore[assignment]
    passed = await r._fetch_video_bytes({"file": "t.mp4", "url": "https://x/t.mp4"})
    assert passed == tiny, "small video must be shipped byte-identical"
    print("ok  _fetch_video_bytes passes a small video through unmodified")

    # ---- over the wire cap => transcoded on the way through
    r._http_get = fake_get  # type: ignore[assignment]
    shrunk = await r._fetch_video_bytes({"file": "b.mp4", "url": "https://x/b.mp4"})
    assert shrunk is not None and len(shrunk) < len(big)
    assert len(shrunk) <= relay.VIDEO_WIRE_MAX_BYTES
    print(f"ok  _fetch_video_bytes downscales a big video ({len(shrunk)} bytes)")

    # ---- a source already under the cap that ffmpeg can't beat is dropped,
    #      not published larger than it arrived
    relay.VIDEO_WIRE_MAX_BYTES = 1  # nothing can hit this
    assert (
        await r._fetch_video_bytes({"file": "b.mp4", "url": "https://x/b.mp4"}) is None
    )
    relay.VIDEO_WIRE_MAX_BYTES = 512 * 1024
    print("ok  _fetch_video_bytes drops what it cannot get under the ceiling")

    # ---- the detached split: a video event must not block the ones behind it
    published = []

    async def fake_publish(rk, body):
        published.append((rk, body))

    r._publish = fake_publish  # type: ignore[assignment]

    async def slow_inline(data):
        if relay._has_video_segment(data):
            await asyncio.sleep(0.2)
            return
        return

    r._inline_media = slow_inline  # type: ignore[assignment]
    vid_ev = {
        "post_type": "message",
        "message": [{"type": "video", "data": {}}],
        "message_id": "vid",
    }
    txt_ev = {
        "post_type": "message",
        "message": [{"type": "text", "data": {}}],
        "message_id": "txt",
    }
    await r._process_event(vid_ev)  # returns immediately, work detached
    await r._process_event(txt_ev)
    assert len(published) == 1, "the text event should already be out"
    assert "txt" in published[0][1], published[0][1]
    await asyncio.gather(*list(r._bg))
    assert len(published) == 2, published
    assert "vid" in published[1][1]
    assert not r._bg, "finished tasks must be discarded from the strong-ref set"
    print("ok  a video does not stall the events behind it (and publishes after)")

    # ---- ts is stamped at publish, so a slow video is not born stale
    import json

    assert json.loads(published[1][1])["ts"] >= json.loads(published[0][1])["ts"]
    print("ok  ts stamped at publish, not receipt")

    print("\nall relay video checks passed")


if __name__ == "__main__":
    asyncio.run(main())
