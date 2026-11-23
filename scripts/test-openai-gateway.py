"""Run with Caddy and OpenSSL in a loopback-only network namespace."""

import http.client
import os
import socket
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Upstream(BaseHTTPRequestHandler):
    def do_POST(self):
        assert self.path == "/v1/responses?stream=true"
        assert self.headers["Host"].split(":")[0] == "api.openai.com"
        assert self.headers.get_all("Authorization") == ["Bearer fake-server-key"]
        assert self.rfile.read(int(self.headers["Content-Length"])) == b"hello"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        self.wfile.write(b"data: first\n\n")
        assert self.server.received.wait(5)
        self.wfile.write(b"data: last\n\n")

    def do_GET(self):
        assert self.headers["Authorization"] == "Bearer fake-server-key"
        self.send_response(429)
        self.send_header("Retry-After", "7")
        self.end_headers()
        self.wfile.write(b"upstream error")


class Proxy(BaseHTTPRequestHandler):
    def do_CONNECT(self):
        assert self.path == "api.openai.com:443"
        self.send_response_only(200)
        self.end_headers()
        with self.server.tls.wrap_socket(self.connection, server_side=True) as conn:
            Upstream(conn, self.client_address, self.server)


def request(method, path, **kwargs):
    conn = http.client.HTTPConnection("127.0.0.1", 61082, timeout=4)
    conn.request(method, path, **kwargs)
    return conn.getresponse()


def check_gateway(tmp):
    assert [name for _, name in socket.if_nameindex()] == ["lo"], "use unshare -Urn"
    config = Path(__file__).resolve().parents[1] / "server/hk/openai-gateway.Caddyfile"
    cert, key = tmp / "cert.pem", tmp / "key.pem"
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-noenc",
            "-days",
            "1",
            "-subj",
            "/CN=api.openai.com",
            "-addext",
            "subjectAltName=DNS:api.openai.com",
            "-out",
            cert,
            "-keyout",
            key,
        ],
        check=True,
        stderr=subprocess.DEVNULL,
    )
    (tmp / "openai-api-key").write_bytes(b"fake-server-key\r\n")
    with ThreadingHTTPServer(("127.0.0.1", 1081), Proxy) as proxy:
        proxy.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        proxy.tls.load_cert_chain(cert, key)
        proxy.received = threading.Event()
        threading.Thread(target=proxy.serve_forever, daemon=True).start()
        env = {
            "PATH": os.environ["PATH"],
            "HOME": str(tmp),
            "SSL_CERT_FILE": str(cert),
            "CREDENTIALS_DIRECTORY": str(tmp),
            "HTTPS_PROXY": "http://127.0.0.1:1081",
        }
        proc = subprocess.Popen(
            ["caddy", "run", "--adapter", "caddyfile", "--config", config], env=env
        )
        try:
            for _ in range(100):
                try:
                    assert request("GET", "/").status == 404
                    break
                except ConnectionRefusedError:
                    assert proc.poll() is None
                    time.sleep(0.05)
            failure = request("GET", "/v1/models")
            assert (
                failure.status,
                failure.getheader("Retry-After"),
                failure.read(),
            ) == (
                429,
                "7",
                b"upstream error",
            )
            stream = request(
                "POST",
                "/v1/responses?stream=true",
                body=b"hello",
                headers={"Authorization": "Bearer client-placeholder"},
            )
            assert stream.status == 200 and stream.readline() == b"data: first\n"
            proxy.received.set()
            assert stream.read() == b"\ndata: last\n\n"
            proxy.shutdown()
            proxy.server_close()
            assert request("GET", "/v1/models").status == 502
        finally:
            proc.terminate()
            proc.wait(timeout=5)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        check_gateway(Path(directory))
    print("PASS: OpenAI gateway forwarding, credentials, streaming and proxy failure")
