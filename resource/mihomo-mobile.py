#!/usr/bin/env python3
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import sys


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {".yaml": "application/yaml"}

    def send_head(self):
        # Nix store timestamps survive content changes.
        del self.headers["If-Modified-Since"]
        return super().send_head()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    address, port, root = sys.argv[1:]
    handler = partial(Handler, directory=root)
    with ThreadingHTTPServer((address, int(port)), handler) as server:
        server.serve_forever()
