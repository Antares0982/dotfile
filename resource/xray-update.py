import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile


def replace_link(path, target):
    temporary = path.with_name(path.name + ".new")
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    temporary.replace(path)


def restart():
    subprocess.run(["sudo", "systemctl", "restart", "xray.service"], check=True)


def update(root, url, template, fetcher, xray, xs):
    root = Path(root)
    os.umask(0o077)
    with (root / "update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        stage = Path(tempfile.mkdtemp(prefix=".generation-", dir=root))
        subscriptions = root / "subscriptions"
        active = root / "config.json"
        previous = subscriptions.resolve() if subscriptions.exists() else None
        selected = active.resolve() if active.exists() else None
        published = False
        try:
            (stage / "sub_url.txt").symlink_to(url)
            env = {
                k: v
                for k, v in os.environ.items()
                if k.lower()
                not in ("http_proxy", "https_proxy", "all_proxy", "no_proxy")
            }
            env.update(XRAY_CONF_DIR=str(stage), XRAY_TEMPLATE=template)
            result = subprocess.run(
                [fetcher, "--headless"],
                env=env,
                timeout=120,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if result.returncode:
                raise RuntimeError("subscription download or generation failed")
            (stage / "sub_url.txt").unlink()
            nodes = stage / "subscriptions"
            files = sorted(nodes.glob("*.json"))
            if not files:
                raise RuntimeError("subscription contains no nodes")
            validated = None
            validation = stage / "validate.json"
            for node in files:
                data = json.loads(node.read_text())
                shared = dict(data)
                outbounds = shared.pop("outbounds")
                shared["outbound_tags"] = [entry.get("tag") for entry in outbounds]
                candidate = node
                if shared == validated:
                    validation.write_text(json.dumps({"outbounds": outbounds}))
                    candidate = validation
                result = subprocess.run(
                    [xray, "-test", "-config", str(candidate)],
                    timeout=30,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                if result.returncode:
                    raise RuntimeError("subscription contains an invalid configuration")
                validated = shared
            validation.unlink(missing_ok=True)
            if selected:
                replace_link(active, selected)
            replace_link(subscriptions, nodes)
            published = True
            (root / "speed_test.json").unlink(missing_ok=True)
            if selected and (nodes / selected.name).is_file():
                replace_link(active, nodes / selected.name)
                restart()
            else:
                if subprocess.run([xs, "Japan"]).returncode:
                    subprocess.run([xs, ""], check=True)
            for generation in root.glob(".generation-*"):
                if generation != stage and (
                    previous is None or generation != previous.parent
                ):
                    shutil.rmtree(generation)
            print("Xray subscription updated", flush=True)
        except BaseException:
            if published:
                if previous:
                    replace_link(subscriptions, previous)
                else:
                    subscriptions.unlink(missing_ok=True)
                if selected:
                    replace_link(active, selected)
                    restart()
                else:
                    active.unlink(missing_ok=True)
                (root / "speed_test.json").unlink(missing_ok=True)
            shutil.rmtree(stage)
            raise


def interrupt(signum, frame):
    raise RuntimeError("subscription update interrupted")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, interrupt)
    try:
        update(*sys.argv[1:])
    except Exception:
        print(
            "Xray subscription update failed; previous configuration retained",
            file=sys.stderr,
        )
        sys.exit(1)
