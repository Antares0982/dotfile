#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../resource/we-layerd-period.sh"
for hour in {00..23}; do
	expected=config.toml
	if ((10#$hour < 6)); then
		expected=night.toml
	elif ((10#$hour >= 19)); then
		expected=evening.toml
	fi
	[[ $(select_config "$hour") == "$expected" ]]
done
for hour in '' 6 24 -1 bad; do
	if select_config "$hour"; then
		exit 1
	fi
done
echo 'Wallpaper time boundaries passed.'
if [[ $# -gt 0 ]]; then
	"${PYTHON:-python3}" - "$1" <<'PY'
import pathlib
import sys
import tomllib

expected = {
    "config.toml": ("3759473977", "3657215414"),
    "evening.toml": ("3545541611", "3780257889"),
    "night.toml": ("3222456142", "3780257889"),
}
for name, ids in expected.items():
    config = tomllib.loads((pathlib.Path(sys.argv[1]) / name).read_text())
    assert not config["renderer"].get("source")
    assert config["renderer"]["assets_path"] == "/var/lib/we-layerd/assets"
    assert config["renderer"]["fps"] == 60
    for output, wallpaper in zip(("HDMI-A-5", "HDMI-A-1"), ids):
        assert config["outputs"][output] == {
            "wallpaper_id": wallpaper,
            "source": f"/var/lib/we-layerd/workshop/{wallpaper}",
        }
        assert config["wallpapers"][wallpaper]["muted"] is True
print("Wallpaper configurations passed.")
PY
fi
