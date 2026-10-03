import io
import os
from pathlib import Path
import runpy
import struct
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
receive = runpy.run_path(str(root / "resource/l4d2/rcon.py"))["receive"]


class Fragments:
    def __init__(self, data):
        self.data = io.BytesIO(data)

    def recv(self, size):
        return self.data.read(min(size, 2))


body = struct.pack("<ii", 2, 0) + "服务器".encode() + b"\0\0"
assert receive(Fragments(struct.pack("<i", len(body)) + body)) == (2, 0, "服务器")
for packet in [
    struct.pack("<i", 9),
    struct.pack("<i", 4097),
    b"",
    struct.pack("<i", 10) + b"x" * 10,
]:
    try:
        receive(Fragments(packet))
    except (ValueError, ConnectionError):
        pass
    else:
        raise AssertionError("Invalid packet accepted")

for mode, expected in [
    ("success", 1),
    ("platform", 2),
    ("network", 2),
    ("failed", 2),
    ("mixed", 2),
]:
    with tempfile.TemporaryDirectory() as directory:
        home = Path(directory)
        tools = home / "bin"
        tools.mkdir()
        steam = tools / "steamcmd"
        steam.write_text("""#!/usr/bin/env bash
set -eu
count=0
if test -f "$HOME/count"; then count=$(cat "$HOME/count"); fi
count=$((count + 1))
echo "$count" > "$HOME/count"
if test "$MODE" = failed; then exit 1; fi
if test "$count" = 1; then
  if test "$MODE" = platform; then echo 'Invalid platform'; exit 0; fi
  if test "$MODE" = network; then exit 1; fi
fi
touch "$HOME/serverfiles/srcds_linux"
chmod +x "$HOME/serverfiles/srcds_linux"
echo "Success! App '222860' fully installed."
if test "$MODE" = mixed; then echo "ERROR! Failed to install app '222860'"; fi
""")
        steam.chmod(0o755)
        proxy = tools / "steam-run"
        proxy.write_text("#!/usr/bin/env bash\nexec steamcmd\n")
        proxy.chmod(0o755)
        env = dict(
            os.environ,
            HOME=str(home),
            MODE=mode,
            PROXY_CONFIG="test",
            PATH=f"{tools}:{os.environ['PATH']}",
        )
        result = subprocess.run(
            ["bash", str(root / "resource/l4d2/update.sh")],
            env=env,
            capture_output=True,
        )
        failed = mode in ("failed", "mixed")
        assert (result.returncode == 0) == (not failed), result.stderr
        assert (home / ".update-incomplete").exists() == failed
        assert int((home / "count").read_text()) == expected
print("L4D2 updater and RCON checks passed")
