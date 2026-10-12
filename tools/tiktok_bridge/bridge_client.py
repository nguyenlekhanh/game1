"""Stdlib-only TCP client for the Cat Commando local game bridge.

Speaks newline-delimited JSON to 127.0.0.1:8765 (defaults).
No third-party packages required.
"""

import json
import socket


class BridgeError(Exception):
    pass


class BridgeClient:
    def __init__(self, host="127.0.0.1", port=8765, timeout=5.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self._sock = None
        self._buf = b""

    def connect(self):
        """Connect to the game. Raises BridgeError with a useful message."""
        self.close()
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(self.timeout)
        try:
            s.connect((self.host, self.port))
        except (ConnectionRefusedError, socket.timeout, OSError) as exc:
            s.close()
            raise BridgeError(
                "Cannot reach the game at %s:%d. Is Cat Commando running? "
                "Launch it first, then retry. (%s)" % (self.host, self.port, exc)
            )
        self._sock = s
        return True

    def close(self):
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None
        self._buf = b""

    @property
    def connected(self):
        return self._sock is not None

    def send(self, payload, await_reply=True):
        """Send one JSON message; optionally read one reply line."""
        if not self.connected:
            self.connect()
        data = (json.dumps(payload) + "\n").encode("utf-8")
        if len(data) > 4096:
            raise BridgeError("Message exceeds the 4 KB bridge limit.")
        try:
            self._sock.sendall(data)
        except OSError as exc:
            self.close()
            raise BridgeError("Send failed, connection dropped: %s" % exc)
        if not await_reply:
            return None
        return self._read_reply()

    def _read_reply(self):
        try:
            while b"\n" not in self._buf:
                chunk = self._sock.recv(4096)
                if not chunk:
                    self.close()
                    return None
                self._buf += chunk
        except socket.timeout:
            return None
        except OSError:
            self.close()
            return None
        line, self._buf = self._buf.split(b"\n", 1)
        try:
            return json.loads(line.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None

    # -- convenience wrappers -------------------------------------------

    def ping(self):
        return self.send({"type": "ping"})

    def send_gift(self, gift_name, username="viewer", count=1, event_id=None):
        payload = {
            "type": "gift",
            "gift_name": gift_name,
            "username": username,
            "count": int(count),
        }
        if event_id:
            payload["event_id"] = str(event_id)
        return self.send(payload)

    def send_command(self, command, username="viewer", count=1, event_id=None):
        payload = {
            "type": "command",
            "command": command,
            "username": username,
            "count": int(count),
        }
        if event_id:
            payload["event_id"] = str(event_id)
        return self.send(payload)
