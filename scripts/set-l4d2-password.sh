#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
encrypted=$(mktemp secrets/.l4d2-password.XXXXXX)
trap 'rm -f "$encrypted"' EXIT
mapfile -t recipients < <(nix eval --offline --json --file secrets/agenix-rules.nix |
	jq -r '."l4d2-files-htpasswd.age".publicKeys[]')
test "${#recipients[@]}" -eq 2
args=()
for recipient in "${recipients[@]}"; do
	args+=(-r "$recipient")
done
htpasswd -nB l4d2 | age "${args[@]}" > "$encrypted"
mv "$encrypted" secrets/l4d2-files-htpasswd.age
echo 'Password encrypted. Rebuild GZ to apply it.'
