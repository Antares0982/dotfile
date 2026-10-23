set -euo pipefail
subs=$1
name=$2
# Trigger filenames identify a single regular node, never a path or active.json.
[[ "$name" != */* && "$name" != active.json && "$name" == *.json ]] || exit 1
node="$subs/$name"
[[ -f "$node" && ! -L "$node" ]] || exit 1
scratch=$(mktemp -d "$subs/.switch.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
if [[ -L "$subs/active.json" ]]; then
	cp -P "$subs/active.json" "$scratch/previous"
elif [[ -e "$subs/active.json" ]]; then
	echo 'xray-switch: active.json must be a symlink' >&2
	exit 1
fi
ln -s "$node" "$scratch/next"
mv -Tf "$scratch/next" "$subs/active.json"
if ! systemctl restart xray; then
	if [[ -L "$scratch/previous" ]]; then
		mv -Tf "$scratch/previous" "$subs/active.json"
	else
		rm -f "$subs/active.json"
	fi
	systemctl restart xray || true
	echo 'xray-switch: restart failed; restored previous selection' >&2
	exit 1
fi
