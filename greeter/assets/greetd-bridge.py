#!/usr/bin/python3
"""
greetd <-> stdio bridge.

greetd speaks length-prefixed JSON over a unix socket: a native-endian u32
byte count followed by that many bytes of JSON. Quickshell's Socket only
splits on a delimiter, so it cannot frame that. This process sits in the
middle and speaks line-delimited JSON on stdio instead, which Process +
SplitParser handles natively.

The protocol is strictly request/response - every request gets exactly one
reply - so a synchronous loop is sufficient and keeps ordering trivially
correct.

stdin  : one request object per line, forwarded verbatim to greetd
stdout : one reply object per line, forwarded verbatim from greetd

Extra locally-generated lines are tagged with a "bridge" key so QML can
tell them apart from real greetd replies.

--demo runs without greetd at all, emulating the protocol so the greeter's
visuals and failure animation can be exercised inside a normal session.
In demo mode any password is rejected except the one in GREETER_DEMO_PW
(default "demo"), and start_session is acknowledged but does nothing.
"""

import json
import os
import socket
import struct
import sys

HEADER = struct.Struct("=I")  # native endian, matching greetd


def emit(obj):
    """Write one JSON line to stdout, flushed - the pipe is our transport."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def note(kind, **kw):
    emit(dict(bridge=kind, **kw))


class Greetd:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)

    def _recv_exactly(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("greetd closed the connection")
            buf += chunk
        return buf

    def request(self, obj):
        payload = json.dumps(obj).encode()
        self.sock.sendall(HEADER.pack(len(payload)) + payload)
        (length,) = HEADER.unpack(self._recv_exactly(HEADER.size))
        return json.loads(self._recv_exactly(length))

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


class DemoGreetd:
    """Emulates just enough of greetd to drive the UI without a daemon."""

    def __init__(self):
        self.password = os.environ.get("GREETER_DEMO_PW", "demo")
        self.session = False

    def request(self, obj):
        kind = obj.get("type")
        if kind == "create_session":
            self.session = True
            return {
                "type": "auth_message",
                "auth_message_type": "secret",
                "auth_message": "Password: ",
            }
        if kind == "post_auth_message_response":
            if obj.get("response") == self.password:
                return {"type": "success"}
            # Deliberately models the stricter of the two readings of greetd's
            # spec: a failed password tears the session down, so the greeter
            # must open a new one before it can retry.
            self.session = False
            return {
                "type": "error",
                "error_type": "auth_error",
                "description": "Authentication failure",
            }
        if kind == "cancel_session":
            if not self.session:
                return {
                    "type": "error",
                    "error_type": "error",
                    "description": "no session to cancel",
                }
            self.session = False
            return {"type": "success"}
        if kind == "start_session":
            return {"type": "success"}
        return {
            "type": "error",
            "error_type": "error",
            "description": f"unknown request {kind!r}",
        }

    def close(self):
        pass


def main():
    demo = "--demo" in sys.argv

    if demo:
        backend = DemoGreetd()
        note("ready", mode="demo")
    else:
        sock_path = os.environ.get("GREETD_SOCK")
        if not sock_path:
            note("fatal", error="GREETD_SOCK is not set")
            return 1
        try:
            backend = Greetd(sock_path)
        except OSError as exc:
            note("fatal", error=f"cannot connect to {sock_path}: {exc}")
            return 1
        note("ready", mode="greetd")

    started = False
    try:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                request = json.loads(line)
            except ValueError as exc:
                note("error", error=f"malformed request: {exc}")
                continue

            # A caller-supplied tag is echoed back on the reply so the greeter
            # can correlate them. Needed because some requests are speculative
            # (a cancel_session that may have nothing to cancel) and their
            # errors must not be mistaken for real authentication errors.
            tag = request.pop("_tag", None)

            try:
                reply = backend.request(request)
            except (OSError, ValueError) as exc:
                note("fatal", error=f"greetd transport failed: {exc}")
                return 1

            if tag is not None:
                reply["_tag"] = tag

            # Once the session is running greetd hands the terminal over and
            # this process is on borrowed time; don't cancel on the way out.
            if request.get("type") == "start_session" and reply.get("type") == "success":
                started = True

            emit(reply)
    except KeyboardInterrupt:
        pass
    finally:
        # A greeter that dies mid-conversation must not leave a half-open
        # session pinned in greetd.
        if not started:
            try:
                backend.request({"type": "cancel_session"})
            except Exception:
                pass
        backend.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
