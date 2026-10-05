"""Reboot monitor for the SONOFF Dongle-M Zigbee coordinator.

Keeps one logged-in WebSocket open to the dongle's web API
(ws://HOST/api/ws). A reboot drops that socket. On every (re)connect the
monitor logs in again and reads the dongle's notification history
(Device.GetNotificationHistory). Every `esp32Start` entry newer than the
last one recorded is a reboot:

- planned:   an `esp32Reboot` entry sits between it and the previous
             `esp32Start` (a reboot the firmware asked for itself)
- unplanned: no `esp32Reboot` before it (crash, watchdog or power loss;
             the API exposes no reset reason that tells these apart)

The history is read once the dongle has been up SETTLE_UPTIME seconds,
since entries made before its clock is set carry a wrong time. If the
history still has no new `esp32Start` but the dongle's uptime (the
`bootTimestamp` pushed after login) shows it booted after the previous
check, the reboot is recorded anyway, with kind "unknown".

Every reboot is appended to STATE_DIR/reboots.jsonl and announced through
a Home Assistant notify service. Alerts that Home Assistant does not take
are kept in STATE_DIR/state.json and retried. On the first run the
reboots already in the history are recorded without alerting.

Read-only towards the dongle: the only requests sent are
Sys.SetLoginState and Device.GetNotificationHistory.
"""

import argparse
import asyncio
import datetime
import hashlib
import http.client
import json
import logging
import os
import secrets
import string
import time
import urllib.request

from websockets.asyncio.client import connect
from websockets.exceptions import WebSocketException

log = logging.getLogger("dongle-m-reboot-monitor")

# The web UI hardcodes the user name.
USERNAME = "admin"
# A rebooting dongle sends no FIN, so a missed pong is how a drop shows.
PING_INTERVAL = PING_TIMEOUT = 20
REPLY_TIMEOUT = 15
RETRY_MIN, RETRY_MAX = 5, 60
# Wait longer after a rejected login, so a wrong password is not retried
# against the dongle every few seconds.
LOGIN_RETRY = 300
# Alert once when the dongle stays unreachable this long. A reboot takes
# well under a minute.
DOWN_ALERT_AFTER = 300
# How often alerts still waiting for Home Assistant are retried.
FLUSH_EVERY = 60
MAX_PENDING = 20
# The dongle's uptime is compared against this host's clock: a fixed
# margin plus 0.1 % of the time since the last check for clock drift.
UPTIME_SLACK, UPTIME_DRIFT = 30, 0.001
# Until the dongle has set its clock, history entries carry the time since
# boot as a 1970 date and are corrected later. Seen live (2026-10-03): the
# new esp32Start read 1970-01-01T00:00:00.925 up to 23 s of uptime and the
# real time from 29 s on. The history is read only once the dongle is this
# old.
SETTLE_UPTIME = 90

ALERT_TITLE = "Zigbee coordinator rebooted"


class LoginError(Exception):
    """The dongle rejected the login, most likely a wrong password."""


class ProtocolError(Exception):
    """The dongle sent something this monitor does not expect."""


def sha256(text):
    return hashlib.sha256(text.encode()).hexdigest()


def parse_time(text):
    try:
        moment = datetime.datetime.fromisoformat(text)
    except (TypeError, ValueError):
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=datetime.timezone.utc)
    return moment


def from_epoch(seconds):
    return datetime.datetime.fromtimestamp(seconds, datetime.timezone.utc)


def local_iso(moment):
    return moment.astimezone().isoformat(timespec="milliseconds")


def clock(record):
    return parse_time(record["time"]).astimezone().strftime("%H:%M:%S")


def duration(seconds):
    if seconds < 60:
        return f"{seconds} s"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes} min"
    return f"{minutes // 60} h {minutes % 60} min"


def read_secret(path):
    with open(path, encoding="utf-8") as f:
        return f.read().rstrip("\r\n")


def login_request(auth, password, seq):
    """Build Sys.SetLoginState for the dongle's sha256 digest scheme."""
    realm, nonce = auth["realm"], auth["nonce"]
    alphabet = string.ascii_letters + string.digits
    cnonce = "".join(secrets.choice(alphabet) for _ in range(8))
    ha1 = sha256(f"{USERNAME}:{realm}:{password}")
    ha2 = sha256("dummy_method:dummy_uri")
    response = sha256(f"{ha1}:{nonce}:{cnonce}:auth:{ha2}")
    return {
        "method": "Sys.SetLoginState",
        "seq": seq,
        "data": {
            "username": USERNAME,
            "realm": realm,
            "nonce": nonce,
            "cnonce": cnonce,
            "qop": "auth",
            "response": response,
            "algorithm": "sha256",
        },
    }


def reboots_in(history, after):
    """Return (start, kind, previous start) for each esp32Start > after."""
    entries = []
    for entry in history:
        moment = parse_time(entry.get("time"))
        if moment is not None:
            entries.append((moment, entry.get("type")))
    entries.sort(key=lambda e: e[0])

    found, previous, planned = [], None, False
    for moment, kind in entries:
        if kind == "esp32Reboot":
            planned = True
        elif kind == "esp32Start":
            if after is None or moment > after:
                found.append(
                    (moment, "planned" if planned else "unplanned", previous)
                )
            previous, planned = moment, False
    return found


class State:
    """state.json (cursor and unsent alerts) plus the reboots.jsonl log."""

    def __init__(self, directory):
        self.path = os.path.join(directory, "state.json")
        self.records_path = os.path.join(directory, "reboots.jsonl")
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
        except FileNotFoundError:
            data = {}
        # False until the first history read: the reboots already in it
        # predate this monitor and are recorded without alerting.
        self.backfilled = data.get("backfilled", False)
        self.last_start = data.get("last_start")
        self.boot_epoch = data.get("boot_epoch")
        self.seen_at = data.get("seen_at")
        self.pending = data.get("pending", [])

    def save(self):
        data = {
            "backfilled": self.backfilled,
            "last_start": self.last_start,
            "boot_epoch": self.boot_epoch,
            "seen_at": self.seen_at,
            "pending": self.pending,
        }
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self.path)

    def append(self, records):
        with open(self.records_path, "a", encoding="utf-8") as f:
            for record in records:
                f.write(json.dumps(record) + "\n")
            f.flush()
            os.fsync(f.fileno())

    def count_since(self, since):
        count = 0
        try:
            with open(self.records_path, encoding="utf-8") as f:
                for line in f:
                    try:
                        moment = parse_time(json.loads(line)["time"])
                    except (ValueError, KeyError, TypeError):
                        continue
                    if moment is not None and moment >= since:
                        count += 1
        except FileNotFoundError:
            pass
        return count


class Monitor:
    def __init__(self, args):
        self.args = args
        self.url = f"ws://{args.host}/api/ws"
        self.state = State(args.state_dir)
        self.password = read_secret(args.password_file)
        self.token = None if args.dry_run else read_secret(args.ha_token_file)
        self.seq = 0
        self.logged_in = False
        self.uptime = None
        self.down_since = None
        self.down_alerted = False
        self.last_error = None

    def next_seq(self):
        self.seq += 1
        return self.seq

    async def run(self):
        retry = RETRY_MIN
        while True:
            try:
                await self.session()
            except LoginError as e:
                self.lost(e)
                wait = LOGIN_RETRY
            except (
                OSError,
                TimeoutError,
                WebSocketException,
                ProtocolError,
            ) as e:
                if self.logged_in:
                    retry = RETRY_MIN
                self.lost(e)
                wait = retry
                retry = min(retry * 2, RETRY_MAX)
            await self.check_down()
            await asyncio.sleep(wait)

    def lost(self, error):
        self.last_error = f"{type(error).__name__}: {error}"
        log.warning("dongle connection lost: %s", self.last_error)
        if self.down_since is None:
            self.down_since = time.time()

    async def check_down(self):
        if self.down_since is None or self.down_alerted:
            await self.flush()
            return
        down_for = int(time.time() - self.down_since)
        if down_for >= DOWN_ALERT_AFTER:
            self.down_alerted = True
            self.queue(
                "Zigbee coordinator unreachable",
                f"The reboot monitor has not reached the Dongle-M for "
                f"{duration(down_for)}. Last error: {self.last_error}",
            )
        await self.flush()

    async def recv(self, ws, timeout):
        raw = await asyncio.wait_for(ws.recv(), timeout)
        try:
            message = json.loads(raw)
        except ValueError:
            raise ProtocolError(f"not JSON: {raw[:200]!r}") from None
        if not isinstance(message, dict):
            raise ProtocolError(f"unexpected frame: {raw[:200]!r}")
        self.on_push(message)
        return message

    async def wait_for(self, ws, match, what):
        deadline = time.monotonic() + REPLY_TIMEOUT
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise ProtocolError(f"timed out waiting for {what}")
            try:
                message = await self.recv(ws, remaining)
            except TimeoutError:
                raise ProtocolError(f"timed out waiting for {what}") from None
            if match(message):
                return message

    def on_push(self, message):
        method = message.get("method")
        data = message.get("data")
        if not isinstance(data, dict):
            return
        if method == "Device.InfoNotify" and "bootTimestamp" in data:
            # Seconds since boot, not an epoch.
            self.uptime = (time.time(), data["bootTimestamp"])
        elif method == "Device.NotificationNotify":
            log.info("dongle notification: %s", json.dumps(data))

    async def session(self):
        self.logged_in = False
        self.uptime = None
        async with connect(
            self.url,
            open_timeout=REPLY_TIMEOUT,
            ping_interval=PING_INTERVAL,
            ping_timeout=PING_TIMEOUT,
            close_timeout=5,
        ) as ws:
            auth = await self.wait_for(
                ws,
                lambda m: m.get("method") == "Sys.AuthRequiredNotify",
                "Sys.AuthRequiredNotify",
            )
            if auth.get("data", {}).get("passwordRequired", True):
                seq = self.next_seq()
                request = login_request(auth["data"], self.password, seq)
                await ws.send(json.dumps(request))
                reply = await self.wait_for(
                    ws, lambda m: m.get("seq") == seq, "the login reply"
                )
                if reply.get("error") != 0:
                    raise LoginError(f"login rejected: {reply.get('error')}")
            self.logged_in = True

            if self.uptime is None:
                try:
                    await self.wait_for(
                        ws, lambda m: self.uptime is not None, "bootTimestamp"
                    )
                except ProtocolError:
                    log.warning("no bootTimestamp after login")
            await self.settle(ws)

            seq = self.next_seq()
            await ws.send(
                json.dumps(
                    {
                        "method": "Device.GetNotificationHistory",
                        "seq": seq,
                        "data": {},
                    }
                )
            )
            reply = await self.wait_for(
                ws, lambda m: m.get("seq") == seq, "the notification history"
            )
            if reply.get("error", 0) != 0:
                raise ProtocolError(f"history request: {reply.get('error')}")
            history = reply.get("data", {}).get("content", [])
            await self.on_login(history)

            while True:
                try:
                    await self.recv(ws, FLUSH_EVERY)
                except TimeoutError:
                    await self.flush()

    async def settle(self, ws):
        """Wait until the dongle has been up for SETTLE_UPTIME seconds."""
        if self.uptime is None:
            return
        seen_at, uptime = self.uptime
        wait = SETTLE_UPTIME - (uptime + time.time() - seen_at)
        if wait <= 0:
            return
        log.info(
            "dongle up %d s, reading its history in %d s", uptime, wait
        )
        deadline = time.monotonic() + wait
        while (remaining := deadline - time.monotonic()) > 0:
            try:
                await self.recv(ws, remaining)
            except TimeoutError:
                break

    async def on_login(self, history):
        now = time.time()
        uptime_note = ""
        if self.uptime is not None:
            seen_at, uptime = self.uptime
            uptime_note = f", up {duration(int(uptime + now - seen_at))}"
        log.info(
            "read %s%s, %d history entries",
            self.args.host,
            uptime_note,
            len(history),
        )
        if self.down_alerted:
            self.queue(
                "Zigbee coordinator reachable again",
                f"The reboot monitor reached the Dongle-M again after "
                f"{duration(int(now - self.down_since))}.",
            )
        self.down_since, self.down_alerted = None, False

        first_run = not self.state.backfilled
        found = reboots_in(history, parse_time(self.state.last_start))
        records = []
        for start, kind, previous in found:
            up_before = None
            if previous is not None:
                up_before = round((start - previous).total_seconds())
            records.append(
                {
                    "time": local_iso(start),
                    "kind": kind,
                    "up_before_s": up_before,
                    "source": "history",
                }
            )
        if found:
            self.state.last_start = found[-1][0].isoformat()

        if self.uptime is not None:
            seen_at, uptime = self.uptime
            boot_epoch = seen_at - uptime
            if not found and self.state.boot_epoch is not None:
                elapsed = seen_at - self.state.seen_at
                slack = UPTIME_SLACK + UPTIME_DRIFT * elapsed
                if boot_epoch - self.state.boot_epoch > slack:
                    records.append(
                        {
                            "time": local_iso(from_epoch(boot_epoch)),
                            "kind": "unknown",
                            "up_before_s": None,
                            "source": "uptime",
                        }
                    )
                    # Should this boot's esp32Start turn up later with a
                    # correct time, it must not count as a second reboot.
                    past = from_epoch(boot_epoch + UPTIME_SLACK)
                    cursor = parse_time(self.state.last_start)
                    if cursor is None or past > cursor:
                        self.state.last_start = past.isoformat()
            self.state.boot_epoch, self.state.seen_at = boot_epoch, seen_at

        for record in records:
            record["alerted"] = not first_run
            record["recorded_at"] = local_iso(from_epoch(now))
        self.state.append(records)
        if first_run:
            log.info(
                "first run: recorded %d earlier reboots from the history "
                "without alerting",
                len(records),
            )
        else:
            for record in records:
                log.info("reboot: %s", json.dumps(record))
            if records:
                self.queue(ALERT_TITLE, self.reboot_message(records, now))
        self.state.backfilled = True
        self.state.save()
        await self.flush()

    def reboot_message(self, records, now):
        day = self.state.count_since(from_epoch(now - 86400))
        if len(records) == 1:
            record = records[0]
            message = (
                f"Dongle-M rebooted at {clock(record)} ({record['kind']})"
            )
            if record["up_before_s"] is not None:
                message += f" after {duration(record['up_before_s'])} up"
        elif len(records) <= 5:
            listed = ", ".join(
                f"{clock(r)} ({r['kind']})" for r in records
            )
            message = f"Dongle-M rebooted {len(records)} times: {listed}"
        else:
            unplanned = sum(r["kind"] == "unplanned" for r in records)
            message = (
                f"Dongle-M rebooted {len(records)} times ({unplanned} "
                f"unplanned) between {clock(records[0])} and "
                f"{clock(records[-1])}"
            )
        return f"{message}. {day} reboots in the last 24 h."

    def queue(self, title, message):
        self.state.pending.append(
            {"title": title, "message": message, "queued_at": time.time()}
        )
        dropped = len(self.state.pending) - MAX_PENDING
        if dropped > 0:
            log.warning("dropping %d unsent alerts", dropped)
            del self.state.pending[:dropped]
        self.state.save()

    async def flush(self):
        sent = 0
        while self.state.pending:
            alert = self.state.pending[0]
            try:
                await asyncio.to_thread(self.notify, alert)
            except (OSError, http.client.HTTPException) as e:
                log.warning("alert not sent, will retry: %s", e)
                break
            self.state.pending.pop(0)
            sent += 1
        if sent:
            self.state.save()

    def notify(self, alert):
        if self.args.dry_run:
            title, message = alert["title"], alert["message"]
            log.info("dry run, alert: %s: %s", title, message)
            return
        body = {
            "title": alert["title"],
            "message": alert["message"],
            # Same Android channel and priority as the HA automation this
            # monitor replaces, so the phone's settings for it carry over.
            "data": {
                "priority": "high",
                "ttl": 0,
                "channel": self.args.channel,
            },
        }
        request = urllib.request.Request(
            f"{self.args.ha_url}/api/services/notify/{self.args.notify}",
            data=json.dumps(body).encode(),
            method="POST",
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=REPLY_TIMEOUT) as reply:
            reply.read()
        log.info("alert sent: %s", alert["message"])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--password-file", required=True)
    parser.add_argument("--ha-url", default="http://127.0.0.1:8124")
    parser.add_argument("--ha-token-file")
    parser.add_argument("--notify", default="mobile_app_pixel_9_pro_xl")
    parser.add_argument("--channel", default="zigbee-coordinator")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="log alerts instead of sending them to Home Assistant",
    )
    args = parser.parse_args()
    if not args.dry_run and not args.ha_token_file:
        parser.error("--ha-token-file is required unless --dry-run")

    # journald adds its own timestamps.
    fmt = "%(levelname)s %(message)s"
    if not os.environ.get("JOURNAL_STREAM"):
        fmt = "%(asctime)s " + fmt
    logging.basicConfig(level=logging.INFO, format=fmt)

    asyncio.run(Monitor(args).run())


if __name__ == "__main__":
    main()
