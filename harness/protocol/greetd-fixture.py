#!/usr/bin/env python3
"""Local greetd IPC fixture. It never invokes PAM or executes session commands."""

import argparse
import json
import os
import signal
import socket
import struct


MAX_FRAME = 1024 * 1024


class FixtureServer:
    def __init__(self, socket_path, status_path, scenario):
        self.socket_path = socket_path
        self.status_path = status_path
        self.scenario = scenario
        self.stopping = False
        self.stage = ""
        self.prompt_count = 0
        self.counts = {
            "create_session": 0,
            "post_auth_message_response": 0,
            "cancel_session": 0,
            "start_session": 0,
        }
        self.start_session_cmd = None
        self.start_session_env = None

    def write_status(self):
        if not self.status_path:
            return
        temporary = self.status_path + ".tmp"
        with open(temporary, "w", encoding="utf-8") as status_file:
            status = dict(self.counts)
            if self.start_session_cmd is not None:
                status["start_session_cmd"] = self.start_session_cmd
            if self.start_session_env is not None:
                status["start_session_env"] = self.start_session_env
            json.dump(status, status_file, sort_keys=True)
            status_file.write("\n")
        os.replace(temporary, self.status_path)

    def send(self, connection, payload):
        encoded = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        connection.sendall(struct.pack("=I", len(encoded)) + encoded)

    def read_exact(self, connection, size):
        chunks = bytearray()
        while len(chunks) < size:
            block = connection.recv(size - len(chunks))
            if not block:
                return None
            chunks.extend(block)
        return bytes(chunks)

    def receive(self, connection):
        header = self.read_exact(connection, 4)
        if header is None:
            return None
        size = struct.unpack("=I", header)[0]
        if size <= 0 or size > MAX_FRAME:
            return None
        payload = self.read_exact(connection, size)
        if payload is None:
            return None
        try:
            request = json.loads(payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None
        return request if isinstance(request, dict) else None

    def send_secret_prompt(self, connection, prompt="Enter your password"):
        self.stage = "prompt-response"
        self.prompt_count = 1
        self.send(connection, {
            "type": "auth_message",
            "auth_message_type": "secret",
            "auth_message": prompt,
        })

    def handle_create(self, connection):
        self.counts["create_session"] += 1
        if self.scenario == "informational-message":
            self.stage = "info-ack"
            self.send(connection, {
                "type": "auth_message",
                "auth_message_type": "info",
                "auth_message": "Touch your security key",
            })
        elif self.scenario == "error-message":
            self.stage = "error-ack"
            self.send(connection, {
                "type": "auth_message",
                "auth_message_type": "error",
                "auth_message": "Security key not detected",
            })
        elif self.scenario == "visible-prompt":
            self.stage = "prompt-response"
            self.prompt_count = 1
            self.send(connection, {
                "type": "auth_message",
                "auth_message_type": "visible",
                "auth_message": "Enter one-time code",
            })
        else:
            self.send_secret_prompt(connection)
        self.write_status()

    def handle_response(self, connection, request):
        self.counts["post_auth_message_response"] += 1
        if self.stage == "info-ack":
            self.send_secret_prompt(connection)
        elif self.stage == "error-ack":
            self.send_secret_prompt(connection)
        elif self.stage == "prompt-response":
            if self.scenario == "multi-prompt" and self.prompt_count == 1:
                self.prompt_count = 2
                self.stage = "prompt-response"
                self.send(connection, {
                    "type": "auth_message",
                    "auth_message_type": "visible",
                    "auth_message": "Enter OTP",
                })
            elif self.scenario == "password-failure":
                self.stage = "terminal"
                self.send(connection, {
                    "type": "error",
                    "error_type": "auth_error",
                    "description": "Authentication failed",
                })
            else:
                self.stage = "ready"
                self.send(connection, {"type": "success"})
        self.write_status()
        # Do not inspect, retain, echo, or log request['response'].
        del request

    def handle_request(self, connection, request):
        kind = request.get("type")
        if kind == "create_session":
            self.handle_create(connection)
        elif kind == "post_auth_message_response":
            self.handle_response(connection, request)
        elif kind == "cancel_session":
            self.counts["cancel_session"] += 1
            self.stage = "cancelled"
            self.write_status()
            if self.scenario == "late-response-after-cancel":
                self.send(connection, {
                    "type": "auth_message",
                    "auth_message_type": "visible",
                    "auth_message": "Late fixture prompt",
                })
        elif kind == "start_session":
            # This fixture has no subprocess or shell launch code. Only the
            # launch-acknowledged scenario acknowledges a request from the
            # ready stage; it records the argv and still executes nothing.
            self.counts["start_session"] += 1
            if self.scenario == "launch-acknowledged" and self.stage == "ready":
                cmd = request.get("cmd")
                if isinstance(cmd, list) and all(isinstance(part, str) for part in cmd):
                    self.start_session_cmd = cmd
                env = request.get("env")
                if isinstance(env, list) and all(isinstance(part, str) for part in env):
                    self.start_session_env = env
                self.stage = "terminal"
                self.write_status()
                self.send(connection, {"type": "success"})
                return
            self.stage = "terminal"
            self.write_status()
            self.send(connection, {
                "type": "error",
                "error_type": "error",
                "description": "Session launch is blocked by the 0.7 fixture",
            })
        else:
            self.send(connection, {
                "type": "error",
                "error_type": "error",
                "description": "Unsupported fixture request",
            })

    def run(self):
        os.umask(0o077)
        try:
            os.unlink(self.socket_path)
        except FileNotFoundError:
            pass

        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(self.socket_path)
            os.chmod(self.socket_path, 0o600)
            listener.listen(1)
            listener.settimeout(0.2)
            while not self.stopping:
                try:
                    connection, _ = listener.accept()
                    break
                except socket.timeout:
                    continue
            else:
                self.write_status()
                return

            with connection:
                connection.settimeout(0.2)
                while not self.stopping:
                    try:
                        request = self.receive(connection)
                    except socket.timeout:
                        continue
                    except (ConnectionError, OSError):
                        break
                    if request is None:
                        break
                    self.handle_request(connection, request)
            self.write_status()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True)
    parser.add_argument("--status-file")
    parser.add_argument(
        "--scenario",
        required=True,
        choices=(
            "password-success",
            "password-failure",
            "multi-prompt",
            "visible-prompt",
            "informational-message",
            "error-message",
            "cancel-during-prompt",
            "late-response-after-cancel",
            "launch-acknowledged",
        ),
    )
    args = parser.parse_args()

    server = FixtureServer(args.socket, args.status_file, args.scenario)

    def stop_server(_signal, _frame):
        server.stopping = True

    signal.signal(signal.SIGTERM, stop_server)
    signal.signal(signal.SIGINT, stop_server)
    server.write_status()
    server.run()


if __name__ == "__main__":
    main()
