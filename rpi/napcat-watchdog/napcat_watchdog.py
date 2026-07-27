"""NapCat offline watchdog — restarts napcat.service when the bot drops offline.

NapCat (v4.18.x) never re-logs-in on its own. When QQ kicks the session its
``onKickedOffLine`` handler only flips ``selfInfo.online`` to false, emits a
``bot_offline`` notice and carries on running; the process stays alive, so
systemd's ``Restart=`` never fires and the bot is silently dead until a human
notices. There is no config knob for a re-login retry loop.

So we watch from outside. This rides NapCat's own OneBot 11 forward-WS server
(the same one the relay talks to) and treats four things as "offline":

  * a ``notice`` event with ``notice_type == "bot_offline"`` (immediate)
  * a ``meta_event`` heartbeat whose ``status.online`` is false
  * a ``get_status`` poll answering ``online: false``
  * the WS server being unreachable for longer than OFFLINE_GRACE, i.e. NapCat
    itself wedged or gone

On a trigger it runs ``systemctl restart``, which re-runs quick login against
the cached session. Restarts are rate limited: RESTART_COOLDOWN after the
first, doubling for every consecutive restart that fails to bring the bot back
(capped at COOLDOWN_MAX), reset the moment the bot is seen online again. A
session killed by risk control usually needs a fresh QR scan, and this keeps
the Pi from restarting NapCat in a tight loop when that happens.

Env:
  NAPCAT_WS_URL        default ws://127.0.0.1:3001
  NAPCAT_WS_TOKEN      optional OneBot access_token (sent as ?access_token=)
  NAPCAT_UNIT          systemd unit to restart (default napcat.service)
  POLL_INTERVAL        get_status poll period, seconds (default 60)
  OFFLINE_GRACE        tolerated WS downtime before restarting (default 180)
  RESTART_COOLDOWN     minimum seconds between restarts (default 900)
  COOLDOWN_MAX         cap for the doubling backoff (default 21600)
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import subprocess
import time

import websockets

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s"
)
_LOG = logging.getLogger("napcat_watchdog")

WS_URL = os.environ.get("NAPCAT_WS_URL", "ws://127.0.0.1:3001")
WS_TOKEN = os.environ.get("NAPCAT_WS_TOKEN", "")
UNIT = os.environ.get("NAPCAT_UNIT", "napcat.service")
POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "60"))
OFFLINE_GRACE = float(os.environ.get("OFFLINE_GRACE", "180"))
RESTART_COOLDOWN = float(os.environ.get("RESTART_COOLDOWN", "900"))
COOLDOWN_MAX = float(os.environ.get("COOLDOWN_MAX", "21600"))
RECONNECT_DELAY = 10

# Echo tag for our own get_status probes, so their responses are told apart
# from the relay's traffic (every event client sees every response it asked for
# only, but the tag also keeps the two pollers' frames unambiguous in logs).
_ECHO_PREFIX = "watchdog-"


class Watchdog:
    def __init__(self) -> None:
        # Assume online at startup: a wedged NapCat then gets a full grace
        # window before the first restart instead of being shot immediately.
        self._last_online = time.monotonic()
        self._last_restart = 0.0
        self._cooldown = RESTART_COOLDOWN
        self._echo_seq = 0

    async def run(self) -> None:
        while True:
            try:
                await self._session()
            except asyncio.CancelledError:
                raise
            except Exception as e:
                _LOG.warning("NapCat WS session ended: %s", e)
            down = time.monotonic() - self._last_online
            if down > OFFLINE_GRACE:
                await self._restart(f"NapCat WS unreachable for {down:.0f}s")
            await asyncio.sleep(RECONNECT_DELAY)

    async def _session(self) -> None:
        url = WS_URL + (f"?access_token={WS_TOKEN}" if WS_TOKEN else "")
        async with websockets.connect(url, max_size=None) as ws:
            _LOG.info("connected to NapCat %s", WS_URL)
            poller = asyncio.create_task(self._poll(ws))
            try:
                async for raw in ws:
                    await self._on_frame(raw)
            finally:
                poller.cancel()

    async def _poll(self, ws) -> None:
        while True:
            self._echo_seq += 1
            await ws.send(
                json.dumps(
                    {
                        "action": "get_status",
                        "params": {},
                        "echo": f"{_ECHO_PREFIX}{self._echo_seq}",
                    }
                )
            )
            await asyncio.sleep(POLL_INTERVAL)

    async def _on_frame(self, raw) -> None:
        try:
            frame = json.loads(raw)
        except ValueError:
            return
        if not isinstance(frame, dict):
            return

        if str(frame.get("echo", "")).startswith(_ECHO_PREFIX):
            data = frame.get("data") or {}
            await self._observe(bool(data.get("online")), "get_status")
            return

        post_type = frame.get("post_type")
        if post_type == "meta_event" and frame.get("meta_event_type") == "heartbeat":
            online = (frame.get("status") or {}).get("online")
            # `online` is optional in NapCat's schema; unknown tells us nothing.
            if online is not None:
                await self._observe(bool(online), "heartbeat")
        elif post_type == "notice" and frame.get("notice_type") == "bot_offline":
            await self._observe(False, f"bot_offline: {frame.get('message')}")

    async def _observe(self, online: bool, source: str) -> None:
        if online:
            self._last_online = time.monotonic()
            if self._cooldown != RESTART_COOLDOWN:
                _LOG.info("bot back online, restart cooldown reset")
                self._cooldown = RESTART_COOLDOWN
            return
        await self._restart(f"bot reported offline ({source})")

    async def _restart(self, reason: str) -> None:
        now = time.monotonic()
        waited = now - self._last_restart
        if self._last_restart and waited < self._cooldown:
            _LOG.warning(
                "%s -- suppressed, %.0fs of the %.0fs cooldown left",
                reason,
                self._cooldown - waited,
                self._cooldown,
            )
            return
        _LOG.error("%s -- restarting %s", reason, UNIT)
        if self._last_restart:
            self._cooldown = min(self._cooldown * 2, COOLDOWN_MAX)
        self._last_restart = now
        # The fresh instance needs time to boot QQ and log in; do not count
        # that startup window against it.
        self._last_online = now
        try:
            await asyncio.to_thread(
                subprocess.run,
                ["systemctl", "restart", UNIT],
                check=True,
                timeout=180,
            )
        except Exception as e:
            _LOG.error("systemctl restart %s failed: %s", UNIT, e)


if __name__ == "__main__":
    asyncio.run(Watchdog().run())
