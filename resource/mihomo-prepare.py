"""Assemble private runtime configuration outside the store."""

import json
import os
from pathlib import Path
import pwd
import secrets
import sys
import tempfile
from urllib.parse import urlsplit


def write_json(path, value):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def prepare(template, subscription):
    os.umask(0o077)
    directory = Path("/var/lib/mihomo-config")
    directory.mkdir(mode=0o700, exist_ok=True)
    url = Path(subscription).read_text().strip()
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or any(c.isspace() for c in url):
        raise ValueError("Subscription must contain one HTTPS URL")
    secret_file = directory / "secret"
    if not secret_file.exists():
        secret_file.write_text(secrets.token_urlsafe(32))
    config = json.loads(Path(template).read_text())
    config["secret"] = secret_file.read_text().strip()
    config["proxy-providers"]["subscription"]["url"] = url
    write_json(directory / "config.json", config)
    client_dir = Path("/run/mihomo-client")
    client_dir.mkdir(mode=0o700, exist_ok=True)
    user = pwd.getpwnam("antares")
    os.chown(client_dir, user.pw_uid, user.pw_gid)
    client_file = client_dir / "connection.json"
    write_json(client_file, {
        "api": "http://127.0.0.1:17900", "secret": config["secret"],
        "port": config["mixed-port"], "test_port": 17901,
    })
    os.chown(client_file, user.pw_uid, user.pw_gid)


if __name__ == "__main__":
    try:
        prepare(*sys.argv[1:])
    except (OSError, ValueError):
        sys.exit("Could not prepare private Mihomo configuration")
