import base64
import http.client
import os
import socket
import subprocess
import tempfile
import time
from pathlib import Path

nginx = os.environ.get("NGINX_BIN", "nginx")
with tempfile.TemporaryDirectory(prefix="nginx-auth-") as temporary:
    root = Path(temporary)
    (root / "outgoing").mkdir()
    password = b"test-password"
    hashed = subprocess.check_output(
        ["openssl", "passwd", "-6", "-stdin"], input=password + b"\n"
    ).strip()
    (root / "htpasswd").write_bytes(b"test-user:" + hashed + b"\n")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    config = root / "nginx.conf"
    config.write_text(f"""
        daemon off;
        master_process off;
        pid {root}/nginx.pid;
        error_log {root}/error.log;
        events {{}}
        http {{
            access_log off;
            server {{
                listen 127.0.0.1:{port};
                root {root};
                auth_basic secured;
                auth_basic_user_file {root}/htpasswd;
                location ~ "^/outgoing/[0-9a-f]{{32}}$" {{
                    dav_methods PUT;
                    dav_access user:rw group:r;
                    create_full_put_path off;
                    client_body_temp_path {root}/tmp;
                    limit_except PUT {{ deny all; }}
                }}
            }}
        }}
    """)
    process = subprocess.Popen(
        [nginx, "-e", str(root / "error.log"), "-p", temporary, "-c", str(config)]
    )
    try:
        for attempt in range(100):
            assert process.poll() is None, (root / "error.log").read_text()
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                    break
            except OSError:
                time.sleep(0.05)
        else:
            raise AssertionError("nginx did not start")
        target = root / "outgoing" / ("1" * 32)
        for supplied, expected in [(None, 401), (b"wrong", 401), (password, 201)]:
            headers = {}
            if supplied is not None:
                token = base64.b64encode(b"test-user:" + supplied).decode()
                headers["Authorization"] = f"Basic {token}"
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
            try:
                connection.request("PUT", "/outgoing/" + target.name, b"test", headers)
                response = connection.getresponse()
                response.read()
                assert response.status == expected, (response.status, expected)
            finally:
                connection.close()
            if expected == 401:
                assert not target.exists()
        assert target.read_bytes() == b"test"
    finally:
        process.terminate()
        process.wait(timeout=5)
print("SHA-512 authentication and upload checks passed")
