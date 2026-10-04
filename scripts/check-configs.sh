#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
	set -- nixos hk rpi5 macbook gz wsl
fi
for host in "$@"; do
	case "$host" in
	nixos | hk | rpi5 | macbook | gz | wsl) ;;
	*)
		echo "Unsupported host: $host" >&2
		exit 2
		;;
	esac
	CHECK_HOST="$host" nix eval --offline --no-write-lock-file --impure --json \
		--expr 'import ./tests/features.nix { root = builtins.getEnv "PWD"; host = builtins.getEnv "CHECK_HOST"; }'
done
