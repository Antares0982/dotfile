"""tri_lug QQ relay — runs on the QQ machine (machine B), next to NapCat.

A dumb pipe between NapCat's OneBot 11 forward-WS server and RabbitMQ. It does
NO translation (that lives in alice's modules/tri_lug_utils/onebot.py); it only:

  * NapCat WS  -> RabbitMQ : events  -> routing key ``qq.event``
                            action responses (have ``echo``) -> ``qq.action_resp``
  * RabbitMQ   -> NapCat WS: ``qq.action`` -> forwarded to NapCat verbatim

Standalone: depends only on ``websockets`` and ``aio_pika`` — it does not import
the alice bot. Configure via environment variables (see below). Designed to run
under systemd with ``Restart=always``; both transports self-reconnect.

Env:
  NAPCAT_WS_URL        default ws://127.0.0.1:3001
  NAPCAT_WS_TOKEN      optional OneBot access_token (sent as ?access_token=)
  TRI_LUG_EXCHANGE     default tri_lug
  RMQ_HOST RMQ_PORT RMQ_USER RMQ_PASS RMQ_VHOST
  RMQ_CAFILE RMQ_CERTFILE RMQ_KEYFILE   (mTLS; if all set, connect over TLS)
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import ssl

import aio_pika
import websockets
from aio_pika import ExchangeType

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s"
)
_LOG = logging.getLogger("qq_relay")

EXCHANGE = os.environ.get("TRI_LUG_EXCHANGE", "tri_lug")
WS_URL = os.environ.get("NAPCAT_WS_URL", "ws://127.0.0.1:3001")
WS_TOKEN = os.environ.get("NAPCAT_WS_TOKEN", "")

RK_EVENT = "qq.event"
RK_ACTION = "qq.action"
RK_ACTION_RESP = "qq.action_resp"

ACTION_QUEUE = "tri_lug.relay.action"


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

    async def run(self) -> None:
        connection = await aio_pika.connect_robust(**_rmq_kwargs())
        channel = await connection.channel()
        self._exchange = await channel.declare_exchange(
            EXCHANGE, ExchangeType.TOPIC, durable=True
        )
        action_q = await channel.declare_queue(ACTION_QUEUE, durable=True)
        await action_q.bind(self._exchange, RK_ACTION)
        await action_q.consume(self._on_action)
        _LOG.info("RabbitMQ ready (exchange=%s)", EXCHANGE)

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
                await self._on_ws_message(raw)

    async def _on_ws_message(self, raw) -> None:
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            return
        if data.get("post_type"):
            await self._publish(RK_EVENT, raw)
        elif "echo" in data and ("retcode" in data or "status" in data):
            await self._publish(RK_ACTION_RESP, raw)

    async def _on_action(self, message: aio_pika.abc.AbstractIncomingMessage) -> None:
        async with message.process():
            if self._ws is None:
                _LOG.warning("action dropped: NapCat WS not connected")
                return
            try:
                await self._ws.send(message.body.decode())
            except Exception as e:
                _LOG.error("failed to forward action to NapCat: %s", e)

    async def _publish(self, routing_key: str, body) -> None:
        assert self._exchange is not None
        if isinstance(body, str):
            body = body.encode()
        await self._exchange.publish(
            aio_pika.Message(body=body), routing_key=routing_key
        )


if __name__ == "__main__":
    asyncio.run(Relay().run())
