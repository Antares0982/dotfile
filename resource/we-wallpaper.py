import argparse
import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=30)


def validate(text):
    config = tomllib.loads(text)
    for output in config["outputs"].values():
        source = Path(output["source"])
        if not source.is_dir() or not os.access(source, os.R_OK | os.X_OK):
            raise ValueError(f"Wallpaper directory is missing or unreadable: {source}")
        with (source / "project.json").open() as project:
            json.load(project)
    return config


def write_config(path, text):
    if text is None:
        path.unlink(missing_ok=True)
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            file.write(text)
            file.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def restart(config, timeout=15):
    run("@systemctl@", "--user", "restart", "we-layerd.service")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            status = tomllib.loads(run("@weLayerd@", "ctl", "status").stdout)
            if (
                status.get("outputs") == config["outputs"]
                and status.get("orchestrator", {}).get("phase") == "running"
                and all(
                    (
                        presentation := status.get("output_runtime", {})
                        .get(output, {})
                        .get("presentation", {})
                    ).get("configured", False)
                    and presentation.get("last_frame_width", 0) > 0
                    and not presentation.get("last_error")
                    for output in config["outputs"]
                )
            ):
                return
        except (subprocess.SubprocessError, tomllib.TOMLDecodeError):
            pass
        time.sleep(0.2)
    raise RuntimeError("Wallpaper service did not become ready; check its journal")


def apply(original, template, override, directory):
    with Path(str(override) + ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = override.read_text() if override.exists() else None
        text = None
        if directory is not None:
            source = str(Path(directory).expanduser().resolve(strict=True))
            text = template.read_text().replace(
                '"@wallpaper-source@"', json.dumps(source, ensure_ascii=False)
            )
        config = validate(text if text is not None else original.read_text())
        write_config(override, text)
        try:
            run(
                "@weLayerd@",
                "print-config",
                "--config",
                str(override if text else original),
            )
            restart(config)
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
            write_config(override, previous)
            try:
                restart(
                    tomllib.loads(
                        previous if previous is not None else original.read_text()
                    )
                )
            except (
                OSError,
                ValueError,
                RuntimeError,
                subprocess.SubprocessError,
            ) as error:
                print(
                    f"we-wallpaper: rollback restart failed: {error}", file=sys.stderr
                )
            raise


def main():
    parser = argparse.ArgumentParser(usage="we-wallpaper [DIRECTORY]")
    parser.add_argument("original", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("template", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("override", type=Path, help=argparse.SUPPRESS)
    parser.add_argument(
        "directory", nargs="?", help="wallpaper directory; omit to restore"
    )
    args = parser.parse_args()
    try:
        apply(args.original, args.template, args.override, args.directory)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"we-wallpaper: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
