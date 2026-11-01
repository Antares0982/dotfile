#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# An existing build can be supplied for repeated checks without rebuilding.
profile=${1:-}
if [[ -z $profile ]]; then
	profile=$(nix build --no-write-lock-file --no-link --print-out-paths --option builders '' \
		./hosts/wsl#nixosConfigurations.wsl.config.system.build.windowsShell)
fi
python3 resource/test_windows_shell.py "$profile"
