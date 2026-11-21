"""Check SZ public services from an external host."""

import http.client
import socket
import sys

host = sys.argv[1] if len(sys.argv) > 1 else "sz.chr.fan"
with socket.create_connection((host, 22), timeout=5) as ssh:
    assert ssh.recv(128).startswith(b"SSH-"), "Missing SSH banner"

https = http.client.HTTPSConnection(host, 8443, timeout=5)
try:
    https.request("HEAD", "/")
    assert https.getresponse().status in (200, 401), "File service unavailable"
finally:
    https.close()

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as game:
    game.settimeout(3)
    game.connect((host, 27015))
    for attempt in range(3):
        game.send(b"\xff\xff\xff\xffqconnect0x00000000\x00")
        try:
            response = game.recv(2048)
        except TimeoutError:
            if attempt == 2:
                raise
        else:
            assert response.startswith(b"\xff\xff\xff\xffA"), "Invalid Source challenge"
            break
print("PASS: public SSH, file HTTPS and Source UDP challenge")
