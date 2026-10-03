import socket
import struct
import sys
from pathlib import Path


def read_exact(conn, size):
    data = bytearray()
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            raise ConnectionError("RCON connection closed")
        data.extend(chunk)
    return bytes(data)


def receive(conn):
    size = struct.unpack("<i", read_exact(conn, 4))[0]
    if not 10 <= size <= 4096:
        raise ValueError("Invalid RCON packet length")
    packet = read_exact(conn, size)
    if packet[-2:] != b"\0\0":
        raise ValueError("Invalid RCON packet terminator")
    ident, kind = struct.unpack("<ii", packet[:8])
    return ident, kind, packet[8:-2].decode("utf-8", errors="replace")


def send(conn, ident, kind, text):
    body = struct.pack("<ii", ident, kind) + text.encode() + b"\0\0"
    conn.sendall(struct.pack("<i", len(body)) + body)


def command(text):
    password = Path("/run/agenix/l4d2-rcon").read_text().strip()
    with socket.create_connection(("127.0.0.1", 27015), timeout=10) as conn:
        send(conn, 1, 3, password)
        while True:
            ident, kind, _ = receive(conn)
            if ident == -1:
                raise PermissionError("RCON authentication failed")
            if kind == 2 and ident == 1:
                break
        send(conn, 2, 2, text)
        send(conn, 3, 0, "")
        output = []
        while True:
            ident, _, body = receive(conn)
            if ident == 3:
                return "".join(output)
            if ident == 2:
                output.append(body)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Usage: l4d2-console <command>")
    print(command(" ".join(sys.argv[1:])), end="")
