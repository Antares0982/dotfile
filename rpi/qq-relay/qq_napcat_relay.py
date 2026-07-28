"""tri_lug QQ relay — runs on the QQ machine (machine B), next to NapCat.

A pipe between NapCat's OneBot 11 forward-WS server and RabbitMQ. It does no
BridgeMessage translation (that lives in alice's modules/tri_lug_utils/onebot.py)
but it DOES enrich events on the way out:

  * NapCat WS  -> RabbitMQ : events -> ``qq.event`` (after fetching image/mface
                            /record bytes and inlining them as base64, and
                            stamping a receipt ``ts``); ``meta_event`` heartbeats
                            dropped. action responses (have ``echo``) ->
                            ``qq.action_resp``
  * RabbitMQ   -> NapCat WS: ``qq.action`` -> forwarded to NapCat verbatim

Image bytes: try an HTTP GET of the segment ``url`` first, then fall back to
NapCat ``get_image``/``get_file`` (read the locally-cached file the bot already
downloaded). Fetched bytes are cached on disk keyed by file id, swept hourly of
anything older than 3h.

Voice bytes (``record``): the segment's url is the raw SILK original, which no
other platform can play, so there is no HTTP path — ``get_record`` is called with
``out_format`` and NapCat (via ffmpeg) hands back the transcoded file inline as
base64. The chosen mime is stamped onto the segment so alice needn't guess. If
NapCat has no ffmpeg the action errors, no bytes are inlined, and alice reports
the message on its log-only path.

Ordering & no deadlock: the WS read loop only classifies frames — events go onto
an in-order internal queue, action responses resolve a pending future or are
forwarded. A single processor task drains the queue in order and does the
(blocking) image fetch; because the read loop keeps running, the relay's own
``get_image`` responses are still read and correlated.

Standalone: depends only on ``websockets``, ``aio_pika`` and ``aiohttp`` — it
does not import the alice bot. Configure via environment variables (see below).
Designed to run under systemd with ``Restart=always``; both transports
self-reconnect.

Env:
  NAPCAT_WS_URL        default ws://127.0.0.1:3001
  NAPCAT_WS_TOKEN      optional OneBot access_token (sent as ?access_token=)
  TRI_LUG_EXCHANGE     default tri_lug
  CACHE_DIR            image cache dir (default /var/cache/qq-napcat-relay)
  ACTION_TIMEOUT       seconds to await a NapCat action response (default 30)
  RMQ_HOST RMQ_PORT RMQ_USER RMQ_PASS RMQ_VHOST
  RMQ_CAFILE RMQ_CERTFILE RMQ_KEYFILE   (mTLS; if all set, connect over TLS)
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import logging
import os
import ssl
import time

import aio_pika
import aiohttp
import websockets
from aio_pika import ExchangeType

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s"
)
_LOG = logging.getLogger("qq_relay")

EXCHANGE = os.environ.get("TRI_LUG_EXCHANGE", "tri_lug")
WS_URL = os.environ.get("NAPCAT_WS_URL", "ws://127.0.0.1:3001")
WS_TOKEN = os.environ.get("NAPCAT_WS_TOKEN", "")
CACHE_DIR = os.environ.get("CACHE_DIR", "/var/cache/qq-napcat-relay")
ACTION_TIMEOUT = float(os.environ.get("ACTION_TIMEOUT", "30"))
CACHE_TTL = 3 * 3600  # drop cached images older than this
HTTP_TIMEOUT = 30

# Voice notes are transcoded out of SILK by NapCat's get_record (ffmpeg). mp3 is
# the safest of the formats it offers: alice forwards it with Telegram
# `send_audio` / Matrix `m.audio`, both of which play it everywhere. Changing
# this needs no change on alice's side — the mime rides along on the segment.
RECORD_FORMAT = "mp3"
RECORD_MIME = "audio/mpeg"

RK_EVENT = "qq.event"
RK_ACTION = "qq.action"
RK_ACTION_RESP = "qq.action_resp"
# Avatar fetch RPC: alice asks the relay for an avatar's raw bytes so it never
# has to reach the QQ avatar CDN itself.
RK_AVATAR_REQ = "qq.avatar_req"
RK_AVATAR_RESP = "qq.avatar_resp"

ACTION_QUEUE = "tri_lug.relay.action"
AVATAR_QUEUE = "tri_lug.relay.avatar"

# QQ avatars are publicly fetchable by uin; s=640 is the large square avatar.
QQ_AVATAR_URL = "https://q1.qlogo.cn/g?b=qq&nk={uin}&s=640"

# Echo prefix for the relay's OWN actions (image fetches), so their responses
# are resolved internally instead of being forwarded to alice as qq.action_resp.
_INTERNAL_ECHO_PREFIX = "relayint-"


def _rmq_kwargs() -> dict:
    kw: dict = {
        "host": os.environ.get("RMQ_HOST", "127.0.0.1"),
        "port": int(os.environ.get("RMQ_PORT", "5672")),
    }
    vhost = os.environ.get("RMQ_VHOST", "/")
    if vhost and vhost != "/":
        kw["virtualhost"] = vhost
    user = os.environ.get("RMQ_USER")
    if user:
        kw["login"] = user
        kw["password"] = os.environ.get("RMQ_PASS", "")
    cafile = os.environ.get("RMQ_CAFILE")
    certfile = os.environ.get("RMQ_CERTFILE")
    keyfile = os.environ.get("RMQ_KEYFILE")
    if cafile and certfile and keyfile:
        ctx = ssl.create_default_context(cafile=cafile)
        ctx.load_cert_chain(certfile=certfile, keyfile=keyfile)
        ctx.verify_flags &= ~ssl.VERIFY_X509_STRICT
        kw["ssl"] = True
        kw["ssl_context"] = ctx
    return kw


class Relay:
    def __init__(self) -> None:
        self._ws: websockets.WebSocketClientProtocol | None = None
        self._exchange: aio_pika.abc.AbstractExchange | None = None
        self._http: aiohttp.ClientSession | None = None
        self._events: asyncio.Queue[dict] = asyncio.Queue()
        self._pending: dict[str, asyncio.Future] = {}
        self._echo_seq = 0
        os.makedirs(CACHE_DIR, exist_ok=True)

    async def run(self) -> None:
        connection = await aio_pika.connect_robust(**_rmq_kwargs())
        channel = await connection.channel()
        self._exchange = await channel.declare_exchange(
            EXCHANGE, ExchangeType.TOPIC, durable=True
        )
        action_q = await channel.declare_queue(ACTION_QUEUE, durable=True)
        await action_q.bind(self._exchange, RK_ACTION)
        await action_q.consume(self._on_action)
        avatar_q = await channel.declare_queue(AVATAR_QUEUE, durable=True)
        await avatar_q.bind(self._exchange, RK_AVATAR_REQ)
        await avatar_q.consume(self._on_avatar)
        self._http = aiohttp.ClientSession()
        _LOG.info("RabbitMQ ready (exchange=%s, cache=%s)", EXCHANGE, CACHE_DIR)

        asyncio.create_task(self._event_processor())
        asyncio.create_task(self._cache_cleanup_loop())

        # Reconnecting WS loop. aio_pika's connection is already robust.
        while True:
            try:
                await self._ws_session()
            except Exception as e:
                _LOG.warning("NapCat WS session ended: %s", e)
            self._ws = None
            await asyncio.sleep(5)

    async def _ws_session(self) -> None:
        url = WS_URL + (f"?access_token={WS_TOKEN}" if WS_TOKEN else "")
        async with websockets.connect(url, max_size=None) as ws:
            self._ws = ws
            _LOG.info("connected to NapCat %s", WS_URL)
            async for raw in ws:
                await self._route_frame(raw)

    # --------------------------------------------------------------- WS inbound
    async def _route_frame(self, raw) -> None:
        """Classify a NapCat frame. Fast: events are queued (kept in order),
        action responses resolve an internal future or are forwarded. No image
        fetching happens here, so a relay-issued get_image response is always
        free to be read on the next iteration."""
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            return
        post_type = data.get("post_type")
        if post_type:
            if post_type == "meta_event":
                return  # heartbeats / lifecycle: not bridged, would flood RMQ
            self._events.put_nowait(data)
            return
        if "echo" in data and ("retcode" in data or "status" in data):
            echo = str(data.get("echo"))
            fut = self._pending.get(echo)
            if fut is not None:  # the relay's own action -> resolve, don't leak
                if not fut.done():
                    fut.set_result(data.get("data"))
                return
            await self._publish(RK_ACTION_RESP, raw)  # alice's action response

    async def _event_processor(self) -> None:
        """Drain events in order, enrich, and publish. Single consumer => the
        order NapCat delivered messages in is preserved on qq.event."""
        while True:
            data = await self._events.get()
            try:
                await self._process_event(data)
            except Exception:
                _LOG.exception("event processing failed")
            finally:
                self._events.task_done()

    async def _process_event(self, data: dict) -> None:
        if data.get("post_type") == "message":
            await self._inline_media(data)
        data["ts"] = time.time()  # receipt stamp (before RabbitMQ)
        await self._publish(RK_EVENT, json.dumps(data))

    async def _inline_media(self, data: dict) -> None:
        """Inline the bytes of every media segment alice can bridge, so it never
        has to reach a Tencent CDN itself. A segment we fail to fetch is left
        untouched — alice then treats it as unbridgeable and logs it."""
        message = data.get("message")
        if not isinstance(message, list):
            return
        for seg in message:
            if not isinstance(seg, dict):
                continue
            stype = seg.get("type")
            sd = seg.get("data")
            if not isinstance(sd, dict):
                continue
            if stype in ("image", "mface"):
                raw_bytes = await self._fetch_image_bytes(sd)
            elif stype == "record":
                raw_bytes = await self._fetch_record_bytes(sd)
                if raw_bytes is not None:
                    sd["mime"] = RECORD_MIME
            else:
                continue
            if raw_bytes is not None:
                sd["base64"] = base64.b64encode(raw_bytes).decode("ascii")

    # ----------------------------------------------------------- media fetching
    async def _fetch_image_bytes(self, data: dict) -> bytes | None:
        file_id = str(data.get("file") or "")
        cached = self._cache_get(file_id) if file_id else None
        if cached is not None:
            return cached

        raw = None
        url = data.get("url")
        if url:
            raw = await self._http_get(url)
        if raw is None and file_id:
            raw = await self._get_image_via_napcat(file_id)
        if raw is None:
            _LOG.warning("could not fetch image bytes (file=%s url=%s)", file_id, url)
            return None
        if file_id:
            self._cache_put(file_id, raw)
        return raw

    async def _fetch_record_bytes(self, data: dict) -> bytes | None:
        """Transcoded bytes of a voice note. No url path: the segment's url is
        the SILK original, so `get_record` (which runs it through ffmpeg) is the
        only useful source. Cached under its own key namespace so the converted
        audio can't collide with an image sharing the same file id."""
        file_id = str(data.get("file") or data.get("file_id") or "")
        if not file_id:
            _LOG.warning("record segment without a file id: %s", data)
            return None
        cache_key = f"record-{RECORD_FORMAT}-{file_id}"
        cached = self._cache_get(cache_key)
        if cached is not None:
            return cached

        # NapCat's get_record takes file *or* file_id and requires out_format; on
        # success it reads the converted file back as base64 for us. It raises
        # (=> no data) when ffmpeg is missing or the format is rejected.
        resp = await self._call_action(
            "get_record", {"file": file_id, "out_format": RECORD_FORMAT}
        )
        raw = await self._bytes_from_file_resp(resp)
        if raw is None:
            _LOG.warning("could not fetch record bytes (file=%s)", file_id)
            return None
        self._cache_put(cache_key, raw)
        return raw

    async def _http_get(self, url: str) -> bytes | None:
        if self._http is None:
            return None
        try:
            timeout = aiohttp.ClientTimeout(total=HTTP_TIMEOUT)
            async with self._http.get(url, timeout=timeout) as resp:
                if resp.status != 200:
                    return None
                return await resp.read()
        except Exception:
            _LOG.warning("image HTTP GET failed: %s", url)
            return None

    async def _get_image_via_napcat(self, file_id: str) -> bytes | None:
        """Ask NapCat for the image it already cached locally."""
        resp = await self._call_action("get_image", {"file": file_id})
        if not resp:
            resp = await self._call_action("get_file", {"file": file_id})
        return await self._bytes_from_file_resp(resp)

    async def _bytes_from_file_resp(self, resp: dict | None) -> bytes | None:
        """Read the payload out of a NapCat file-action response (get_image /
        get_file / get_record): prefer an inline base64, else read the local file
        it points at, else GET its url. `url` is only worth a request when it is
        actually remote — get_record, for one, sets it to the local output path."""
        if not resp:
            return None
        b64 = resp.get("base64")
        if b64:
            try:
                return base64.b64decode(b64)
            except (ValueError, TypeError):
                pass
        path = resp.get("file")
        if path and os.path.isfile(path):
            try:
                with open(path, "rb") as f:
                    return f.read()
            except OSError:
                _LOG.warning("could not read local file %s", path)
        url = resp.get("url")
        if url and str(url).startswith("http"):
            return await self._http_get(url)
        return None

    async def _call_action(self, action: str, params: dict) -> dict | None:
        """Relay-internal OneBot action RPC over the WS, echo-tagged so its
        response is resolved here (not forwarded to alice)."""
        if self._ws is None:
            return None
        self._echo_seq += 1
        echo = f"{_INTERNAL_ECHO_PREFIX}{self._echo_seq}"
        fut: asyncio.Future = asyncio.get_running_loop().create_future()
        self._pending[echo] = fut
        try:
            await self._ws.send(
                json.dumps({"action": action, "params": params, "echo": echo})
            )
        except Exception:
            self._pending.pop(echo, None)
            return None
        try:
            return await asyncio.wait_for(fut, timeout=ACTION_TIMEOUT)
        except asyncio.TimeoutError:
            _LOG.warning("relay action %s timed out (echo=%s)", action, echo)
            return None
        finally:
            self._pending.pop(echo, None)

    # ------------------------------------------------------------- image cache
    def _cache_path(self, file_id: str) -> str:
        safe = "".join(c if (c.isalnum() or c in "._-") else "_" for c in file_id)
        if not safe or len(safe) > 200:
            safe = hashlib.sha1(file_id.encode("utf-8")).hexdigest()
        return os.path.join(CACHE_DIR, safe)

    def _cache_get(self, file_id: str) -> bytes | None:
        path = self._cache_path(file_id)
        try:
            with open(path, "rb") as f:
                return f.read()
        except OSError:
            return None

    def _cache_put(self, file_id: str, raw: bytes) -> None:
        path = self._cache_path(file_id)
        try:
            tmp = f"{path}.tmp"
            with open(tmp, "wb") as f:
                f.write(raw)
            os.replace(tmp, path)
        except OSError:
            _LOG.warning("could not write image cache %s", path)

    async def _cache_cleanup_loop(self) -> None:
        while True:
            await asyncio.sleep(3600)
            cutoff = time.time() - CACHE_TTL
            try:
                for name in os.listdir(CACHE_DIR):
                    p = os.path.join(CACHE_DIR, name)
                    try:
                        if os.path.isfile(p) and os.path.getmtime(p) < cutoff:
                            os.remove(p)
                    except OSError:
                        pass
            except OSError:
                pass

    # ------------------------------------------------------------- RMQ outbound
    async def _on_action(self, message: aio_pika.abc.AbstractIncomingMessage) -> None:
        async with message.process():
            if self._ws is None:
                _LOG.warning("action dropped: NapCat WS not connected")
                return
            try:
                await self._ws.send(message.body.decode())
            except Exception as e:
                _LOG.error("failed to forward action to NapCat: %s", e)

    async def _on_avatar(self, message: aio_pika.abc.AbstractIncomingMessage) -> None:
        async with message.process():
            try:
                req = json.loads(message.body)
            except (ValueError, TypeError):
                return
            echo = req.get("echo")
            uin = str(req.get("id", ""))
            resp: dict = {"echo": echo}
            # kind is "qq" for now; other platforms fetch their own avatars.
            if uin:
                raw = await self._http_get(QQ_AVATAR_URL.format(uin=uin))
                if raw:
                    resp["base64"] = base64.b64encode(raw).decode("ascii")
            await self._publish(RK_AVATAR_RESP, json.dumps(resp))

    async def _publish(self, routing_key: str, body) -> None:
        assert self._exchange is not None
        if isinstance(body, str):
            body = body.encode()
        await self._exchange.publish(
            aio_pika.Message(body=body), routing_key=routing_key
        )


if __name__ == "__main__":
    asyncio.run(Relay().run())
