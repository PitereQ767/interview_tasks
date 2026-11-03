"""Small dependency-free HTTP application for the interview exercises."""

import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.respond(200, b"ok\n", "text/plain")
        elif self.path == "/":
            body = json.dumps(
                {
                    "message": os.environ.get(
                        "APP_MESSAGE", "Hello from the interview app"
                    ),
                    "hostname": socket.gethostname(),
                }
            ).encode() + b"\n"
            self.respond(200, body, "application/json")
        else:
            self.respond(404, b"not found\n", "text/plain")

    def respond(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"Listening on 0.0.0.0:{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
