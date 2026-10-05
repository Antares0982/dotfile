import base64
from html.parser import HTMLParser
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


class Links(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.urls = []
        self.images = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            self.urls.append(attrs["href"])
        if tag == "img":
            self.images.append(attrs["src"])


root = Path(__file__).resolve().parents[1]
nginx = os.environ.get("NGINX_BIN", "nginx")
htpasswd = os.environ.get("HTPASSWD_BIN", "htpasswd")
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
with tempfile.TemporaryDirectory() as temporary:
    work = Path(temporary)
    addons = work / "addons"
    addons.mkdir()
    files = {
        "map.vpk": b"vpk-content" * 100,
        "中文 & <地图> #?%\"'.VPK": b"special-name",
        "preview.JpG": b"\xff\xd8\xff\xd9",
    }
    for name, data in files.items():
        (addons / name).write_bytes(data)
    for name in ["private.cfg", "index.html", ".hidden.vpk", "test.jpeg"]:
        (addons / name).write_text("private fixture")
    (addons / "nested.vpk").mkdir()
    (addons / "nested.vpk" / "secret.vpk").write_text("private fixture")
    (work / "outside.vpk").write_text("private fixture")
    (addons / "link.vpk").symlink_to(work / "outside.vpk")
    (work / "htpasswd").write_bytes(
        subprocess.check_output([htpasswd, "-niB", "l4d2"], input=b"test-password\n")
    )
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    snippet = (
        (root / "resource/l4d2/files.conf")
        .read_text()
        .replace("@stylesheet@", str(root / "resource/l4d2/files.xsl"))
    )
    config = work / "nginx.conf"
    config.write_text(f"""
        daemon off;
        pid {work}/nginx.pid;
        error_log {work}/error.log;
        events {{ }}
        http {{
            access_log off;
            client_body_temp_path {work}/body;
            proxy_temp_path {work}/proxy;
            fastcgi_temp_path {work}/fastcgi;
            uwsgi_temp_path {work}/uwsgi;
            scgi_temp_path {work}/scgi;
            server {{
                listen 127.0.0.1:{port};
                root {addons};
                auth_basic "L4D2";
                auth_basic_user_file {work}/htpasswd;
                {snippet}
            }}
        }}
    """)
    subprocess.run(
        [
            nginx,
            "-t",
            "-e",
            str(work / "error.log"),
            "-p",
            temporary,
            "-c",
            str(config),
        ],
        check=True,
    )
    process = subprocess.Popen(
        [nginx, "-e", str(work / "error.log"), "-p", temporary, "-c", str(config)]
    )

    def request(path, password="test-password", method="GET", headers=None):
        headers = dict(headers or {})
        if password is not None:
            token = base64.b64encode(f"l4d2:{password}".encode()).decode()
            headers["Authorization"] = f"Basic {token}"
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}{path}", headers=headers, method=method
        )
        try:
            response = opener.open(req, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()

    try:
        for attempt in range(100):
            assert process.poll() is None, (work / "error.log").read_text()
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                    break
            except OSError:
                time.sleep(0.05)
        else:
            raise AssertionError("nginx did not start")
        for path in ["/", "/map.vpk", "/preview.JpG"]:
            for password in [None, "wrong"]:
                assert request(path, password)[0] == 401
        status, headers, body = request("/")
        assert status == 200 and headers.get_content_type() == "text/html"
        html = body.decode()
        assert "private fixture" not in html
        page = Links(html)
        assert page.images == ["/preview.JpG"]
        for name, data in files.items():
            path = "/" + urllib.parse.quote(name, safe="")
            assert any(urllib.parse.unquote(url) == "/" + name for url in page.urls)
            assert request(path)[2] == data
            assert request(path, method="HEAD")[2] == b""
        assert request("/preview.JpG")[1].get_content_type() == "image/jpeg"
        assert request("/map.vpk")[1].get_content_type() == "application/octet-stream"
        status, headers, body = request("/map.vpk", headers={"Range": "bytes=3-8"})
        assert status == 206 and body == files["map.vpk"][3:9]
        for path in [
            "/private.cfg",
            "/index.html",
            "/.hidden.vpk",
            "/test.jpeg",
            "/nested.vpk",
            "/nested.vpk/",
            "/nested.vpk/secret.vpk",
            "/nested.vpk%2fsecret.vpk",
            "/%2e%2e/outside.vpk",
            "/link.vpk",
        ]:
            assert request(path)[0] in (400, 403, 404), path
        for name in [
            "private.cfg",
            "index.html",
            ".hidden.vpk",
            "nested.vpk",
            "test.jpeg",
        ]:
            assert "/" + name not in page.urls
        for method in ["POST", "PUT", "DELETE"]:
            assert request("/map.vpk", method=method)[0] in (403, 405)
        assert (addons / "map.vpk").read_bytes() == files["map.vpk"]
        (addons / "new.vpk").write_text("new")
        assert "/new.vpk" in Links(request("/")[2].decode()).urls
        (addons / "new.vpk").unlink()
        assert "/new.vpk" not in Links(request("/")[2].decode()).urls
        assert request("/new.vpk")[0] == 404
    finally:
        process.terminate()
        process.wait(timeout=10)
print("L4D2 download checks passed")
