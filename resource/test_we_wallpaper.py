import importlib.util
import json
import subprocess
import tempfile
import tomllib
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "wallpaper", Path(__file__).with_name("we-wallpaper.py")
)
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


def config(source):
    return "\n".join(
        f'[outputs."{output}"]\nwallpaper_id = "{output}"\nsource = {json.dumps(str(source))}'
        for output in ("HDMI-A-5", "HDMI-A-1")
    )


def fails(action):
    try:
        action()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        return
    raise AssertionError("Expected failure")


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / '壁纸 "quoted" \\ path'
        source.mkdir()
        (source / "project.json").write_text("{}")
        original = root / "original.toml"
        original.write_text(config(source))
        template = root / "template.toml"
        template.write_text(config("@wallpaper-source@"))
        override = root / "override.toml"
        with (
            patch.object(wallpaper, "run"),
            patch.object(wallpaper, "restart") as restart,
        ):
            wallpaper.apply(original, template, override, str(source))
            first = override.read_text()
            assert all(
                v["source"] == str(source)
                for v in tomllib.loads(first)["outputs"].values()
            )
            restart.assert_called_once_with(tomllib.loads(first))
            second = root / "second"
            second.mkdir()
            (second / "project.json").write_text("{}")
            wallpaper.apply(original, template, override, str(second))
            assert all(
                v["source"] == str(second)
                for v in tomllib.loads(override.read_text())["outputs"].values()
            )
            wallpaper.apply(original, template, override, None)
            assert not override.exists()
            restart.assert_called_with(tomllib.loads(original.read_text()))
            wallpaper.apply(original, template, override, None)
            restart.reset_mock()
            for invalid in (root / "missing", source / "project.json", root):
                fails(
                    lambda invalid=invalid: wallpaper.apply(
                        original, template, override, str(invalid)
                    )
                )
                assert not override.exists()
            restart.assert_not_called()
            override.write_text(first)
            original.write_text(config(root / "missing"))
            fails(lambda: wallpaper.apply(original, template, override, None))
            assert override.read_text() == first
            restart.assert_not_called()
            original.write_text(config(source))

        for previous in (None, first):
            wallpaper.write_config(override, previous)
            with (
                patch.object(wallpaper, "run"),
                patch.object(
                    wallpaper, "restart", side_effect=[RuntimeError("failed"), None]
                ) as restart,
            ):
                fails(
                    lambda: wallpaper.apply(original, template, override, str(second))
                )
                assert (override.read_text() if override.exists() else None) == previous
                assert restart.call_count == 2
                restart.assert_called_with(
                    tomllib.loads(previous or original.read_text())
                )
        override.write_text(first)
        with (
            patch.object(wallpaper, "run"),
            patch.object(
                wallpaper, "restart", side_effect=[RuntimeError("failed"), None]
            ),
        ):
            fails(lambda: wallpaper.apply(original, template, override, None))
            assert override.read_text() == first

        expected = tomllib.loads(first)
        status = (
            first
            + '\n[orchestrator]\nphase = "running"\n'
            + "\n".join(
                f'[output_runtime."{output}".presentation]\nconfigured = true\nlast_frame_width = 1920'
                for output in expected["outputs"]
            )
        )
        with patch.object(
            wallpaper, "run", return_value=subprocess.CompletedProcess([], 0, status)
        ):
            wallpaper.restart(expected)
        with (
            patch.object(
                wallpaper, "run", return_value=subprocess.CompletedProcess([], 0, first)
            ),
            patch.object(wallpaper.time, "monotonic", side_effect=[0, 0, 16]),
            patch.object(wallpaper.time, "sleep"),
        ):
            fails(lambda: wallpaper.restart(expected))
    print("Wallpaper override checks passed.")


if __name__ == "__main__":
    main()
