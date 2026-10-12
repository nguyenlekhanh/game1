"""Cat Commando TikTok LIVE connector.

Watches a public TikTok LIVE room for gift events and forwards them as
game commands to the local Cat Commando bridge (127.0.0.1:8765).

IMPORTANT - please read:
- TikTokLive is an UNOFFICIAL, reverse-engineered library. TikTok may
  change its protocol at any time; if connection fails with sign/API
  errors, that is a TikTok-side restriction, not a game bug. The program
  prints the real error instead of pretending to be connected.
- No TikTok password, session cookie, or API key is needed or collected.
  You only provide the streamer's public @username.

Usage:
    pip install -r requirements.txt
    python connector.py --user YOUR_TIKTOK_USERNAME
    python connector.py --user @someone --config my_mapping.json

Gift -> command translation comes from gift_mapping.json (same folder).
Per-command cooldowns and boss/enemy caps are enforced by the game.
"""

import argparse
import asyncio
import json
import os
import sys
import time
import uuid

try:
    from TikTokLive import TikTokLiveClient
    from TikTokLive.events import (
        ConnectEvent,
        DisconnectEvent,
        GiftEvent,
        LiveEndEvent,
    )
except ImportError:
    print("ERROR: the 'TikTokLive' package is not installed.", file=sys.stderr)
    print("Install it first:  pip install -r requirements.txt", file=sys.stderr)
    sys.exit(2)

from bridge_client import BridgeClient, BridgeError

HERE = os.path.dirname(os.path.abspath(__file__))
KNOWN_COMMANDS = {
    "rapid_fire", "giant_gun",
    "weapon_minigun", "weapon_rocket", "weapon_machinegun", "weapon_default",
    "mega_laser", "spawn_wave", "summon_boss",
}


def load_mapping(path):
    with open(path, "r", encoding="utf-8") as fh:
        cfg = json.load(fh)
    raw = cfg.get("mappings", {})
    mappings = {}
    for gift_name, command in raw.items():
        if command not in KNOWN_COMMANDS:
            print("WARNING: mapping '%s' -> unknown command '%s' disabled. "
                  "Known: %s" % (gift_name, command, sorted(KNOWN_COMMANDS)))
            continue
        mappings[str(gift_name).strip().lower()] = command
    return cfg, mappings


def extract_gift_info(event):
    """Return (gift_name, username, count, is_final) or None to ignore.

    Streakable gifts (type == 1) fire one event per increment; only the
    final event (repeat_end == 1 / streaking finished) activates the game,
    with repeat_count as the quantity. Non-streakable gifts act immediately.
    Defensive getattr() calls keep this working if the library renames
    fields in a future version.
    """
    gift = getattr(event, "gift", None)
    if gift is None:
        return None
    name = getattr(gift, "name", "") or ""
    if not name:
        return None
    user = getattr(event, "user", None)
    username = getattr(user, "unique_id", "viewer") or "viewer"
    gtype = getattr(gift, "type", 0)
    if gtype == 1:
        # Streakable: skip intermediate events, act once at streak end.
        if getattr(event, "streaking", False):
            return None
        count = getattr(event, "repeat_count", 1) or 1
    else:
        count = 1
    try:
        count = max(1, int(count))
    except (TypeError, ValueError):
        count = 1
    return name, str(username), count, True


async def run_connector(username, cfg, mappings, args):
    if not username.startswith("@"):
        username = "@" + username
    host = args.host or cfg.get("godot_host", "127.0.0.1")
    port = args.port or int(cfg.get("godot_port", 8765))
    wave_per = int(cfg.get("wave_enemies_per_gift", 2))
    wave_max = int(cfg.get("wave_max", 10))

    bridge = BridgeClient(host, port)
    try:
        bridge.connect()
    except BridgeError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 3
    reply = bridge.ping()
    print("Game bridge: %s:%d %s (reply=%s). Launch the game first if this fails."
          % (host, port, "OK" if reply else "UNREACHABLE", reply))

    client = TikTokLiveClient(unique_id=username)

    @client.on(ConnectEvent)
    async def on_connect(event):
        print("Connected to @%s (room %s). Listening for gifts..."
              % (getattr(event, "unique_id", username), getattr(client, "room_id", "?")))

    @client.on(DisconnectEvent)
    async def on_disconnect(_event):
        print("Disconnected from TikTok. Reconnect logic in main loop applies.")

    @client.on(LiveEndEvent)
    async def on_live_end(_event):
        print("Livestream ended. Stopping connector (restart it for the next LIVE).")

    @client.on(GiftEvent)
    async def on_gift(event):
        try:
            info = extract_gift_info(event)
            if info is None:
                return
            gift_name, viewer, count, _final = info
            key = gift_name.strip().lower()
            if key not in mappings:
                print("Unmapped gift '%s' from %s ignored (edit gift_mapping.json)."
                      % (gift_name, viewer))
                return
            command = mappings[key]
            payload_count = count
            if command == "spawn_wave":
                payload_count = max(1, min(count * wave_per, wave_max))
            # One UUID per completed gift event. TikTok exposes no stable
            # gift-event id, so a transport retry reuses this id and the
            # game dedups it: retried messages can never double-count.
            event_id = str(uuid.uuid4())
            try:
                try:
                    result = await asyncio.to_thread(
                        bridge.send_command, command, viewer, payload_count, event_id)
                except BridgeError:
                    print("Bridge send failed, reconnecting once (same event id)...")
                    await asyncio.to_thread(bridge.connect)
                    result = await asyncio.to_thread(
                        bridge.send_command, command, viewer, payload_count, event_id)
            except BridgeError as exc:
                print("Bridge send failed: %s" % exc)
                return
            print("Gift '%s' x%d from %s -> %s (game: %s)"
                  % (gift_name, count, viewer, command, result))
        except Exception as exc:  # never let one bad event kill the loop
            print("Gift handler error (ignored): %r" % exc)

    # Pre-check: fail fast with a clear message if nobody is LIVE.
    try:
        live = await client.is_live()
    except Exception as exc:
        print("ERROR: could not reach TikTok (%r)." % exc, file=sys.stderr)
        print("Check your internet connection and that the TikTok API is reachable.", file=sys.stderr)
        return 4
    if not live:
        print("ERROR: @%s is not LIVE right now." % username.lstrip("@"), file=sys.stderr)
        print("Start the TikTok LIVE first, or test offline with:  python simulate.py", file=sys.stderr)
        return 5

    print("Confirmed @%s is LIVE. Connecting..." % username.lstrip("@"))
    try:
        try:
            await client.start(fetch_gift_info=True)
        except TypeError:
            # Older/newer library builds without this kwarg: connect plain.
            await client.start()
        # Keep running until disconnect / Ctrl+C.
        while client.connected:
            await asyncio.sleep(1.0)
    except (KeyboardInterrupt, asyncio.CancelledError):
        print("\nStopping (Ctrl+C).")
    except Exception as exc:
        print("ERROR: TikTok connection failed: %r" % exc, file=sys.stderr)
        print("This usually means TikTok changed its protocol or rate-limited "
              "the sign server. Check for a TikTokLive update: pip install -U TikTokLive",
              file=sys.stderr)
        return 6
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass
        bridge.close()
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Cat Commando TikTok LIVE connector")
    parser.add_argument("--user", default="",
                        help="Streamer TikTok username (with or without @). Overrides config file.")
    parser.add_argument("--config", default=os.path.join(HERE, "gift_mapping.json"),
                        help="Path to gift mapping JSON.")
    parser.add_argument("--host", default=None,
                        help="Game bridge host (overrides config file).")
    parser.add_argument("--port", type=int, default=None,
                        help="Game bridge port (overrides config file).")
    parser.add_argument("--retries", type=int, default=5,
                        help="Reconnect attempts on TikTok failures (0 = no retry).")
    parser.add_argument("--retry-delay", type=float, default=10.0,
                        help="Seconds between reconnect attempts.")
    args = parser.parse_args(argv)

    try:
        cfg, mappings = load_mapping(args.config)
    except (OSError, ValueError) as exc:
        print("ERROR: cannot load mapping file '%s': %s" % (args.config, exc), file=sys.stderr)
        return 2

    username = args.user.strip() or str(cfg.get("tiktok_username", "")).strip()
    if not username:
        print("ERROR: no TikTok username. Use --user @someone or set "
              '"tiktok_username" in gift_mapping.json.', file=sys.stderr)
        return 2
    print("Active gift mappings (%d):" % len(mappings))
    for gift_name in sorted(mappings):
        print("  %-14s -> %s" % (gift_name, mappings[gift_name]))
    if not mappings:
        print("WARNING: no valid mappings; gifts will only be logged, game idle.")

    attempt = 0
    while True:
        code = asyncio.run(run_connector(username, cfg, mappings, args))
        if code in (0, 2, 3, 5):  # clean stop / config / bridge-down / not-live: don't loop
            return code
        attempt += 1
        if args.retries > 0 and attempt > args.retries:
            print("Giving up after %d attempts." % args.retries, file=sys.stderr)
            return code
        wait = min(args.retry_delay * attempt, 120.0)
        print("Retrying in %.0fs (attempt %d)... Ctrl+C to stop." % (wait, attempt + 1))
        try:
            time.sleep(wait)
        except KeyboardInterrupt:
            print("\nStopping.")
            return 0


if __name__ == "__main__":
    sys.exit(main())
