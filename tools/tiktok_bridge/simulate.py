
"""Cat Commando: send exactly ONE test gift per execution.

Usage:
    python simulate.py
    python simulate.py --gift Galaxy
    python simulate.py --gift Rose

The script never resets the game, fills the queue, or kills bosses.
Run it again manually whenever you want to send another test gift.
"""

import argparse
import time

from bridge_client import BridgeClient, BridgeError


def main():
    parser = argparse.ArgumentParser(
        description="Send exactly one test gift to Cat Commando"
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--gift", default="Galaxy",
                        help="Gift name (default: Galaxy)")
    parser.add_argument("--username", default="sim_viewer")
    args = parser.parse_args()

    client = BridgeClient(args.host, args.port)

    try:
        print(f"Connecting to game at {args.host}:{args.port} ...")
        client.connect()
        print("Connected.")

        # Read state before sending anything.
        before = client.send({"type": "status"})
        print(f"Before: {before}")

        # Send exactly ONE gift event. No loops and no automatic retries.
        print(f"Sending exactly ONE {args.gift} gift...")
        result = client.send_gift(args.gift, args.username, 1)
        print(f"Gift result: {result}")

        # Give Godot a brief moment to register deferred boss spawning.
        time.sleep(0.25)

        after = client.send({"type": "status"})
        print(f"After:  {after}")

        if isinstance(result, dict) and result.get("ok") is True:
            print("\nGift request accepted.")
        else:
            print("\nGift was rejected or not accepted. Check the result above.")

        print("This run sent one gift only. No additional gifts were sent.")

        return 0

    except BridgeError as exc:
        print(f"Bridge connection error: {exc}")
        return 1
    except Exception as exc:
        print(f"Unexpected error: {exc}")
        return 1
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
