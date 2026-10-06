#!/usr/bin/env bash
set -euo pipefail
sz_key=
if [[ ${1:-} == --sz-key && $# -ge 2 ]]; then
	sz_key=$(realpath "$2")
	shift 2
fi
if (($# < 4 || $# > 5)); then
	echo "Usage: $0 [--sz-key SZ_KEY] ADMIN_KEY RPI_KEY HK_KEY GZ_KEY [BEFORE_SECRETS_DIR]" >&2
	exit 2
fi
keys=("$(realpath "$1")" "$(realpath "$2")" "$(realpath "$3")" "$(realpath "$4")")
hosts=(admin rpi5 hk gz)
if [[ -n $sz_key ]]; then
	keys+=("$sz_key")
	hosts+=(sz)
fi
before=${5:+$(realpath "$5")}
cd "$(dirname "$0")/.."
age=${AGE_BIN:-age}
command -v "$age" >/dev/null
rules=$(nix eval --offline --json --file secrets/agenix-rules.nix)
files=$(printf '%s\n' secrets/*.age | sed 's|^secrets/||' | jq -Rsc 'split("\n")[:-1] | sort')
jq -en --argjson rules "$rules" --argjson files "$files" \
	'($rules | keys) == $files' >/dev/null
public=()
for key in "${keys[@]}"; do
	public+=("$(cat "$key" | ssh-keygen -y -P '' -f /dev/stdin | awk '{print $1 " " $2}')")
done
expected=$(jq -cn --argjson files "$files" --arg key "${public[0]}" \
	'$files | map({key: ., value: [$key]}) | from_entries')
for ((i = 1; i < ${#keys[@]}; i++)); do
	host=${hosts[$i]}
	used=$(nix eval --offline --no-write-lock-file --json \
		"./hosts/$host#nixosConfigurations.$host.config.age.secrets" \
		--apply 's: builtins.attrValues (builtins.mapAttrs (_: v: builtins.baseNameOf v.file) s)' | jq 'unique')
	expected=$(jq -cn --argjson expected "$expected" --argjson used "$used" \
		--arg key "${public[$i]}" \
		'$expected | reduce $used[] as $file (. ; .[$file] += [$key])')
done
jq -en --argjson rules "$rules" --argjson expected "$expected" \
	'($rules | map_values(.publicKeys | sort)) == ($expected | map_values(sort))' >/dev/null || {
	echo 'FAIL: recipient rules differ from enabled host secrets' >&2
	exit 1
}
for file in secrets/*.age; do
	name=${file##*/}
	for i in "${!keys[@]}"; do
		allowed=false
		if jq -e --arg file "$name" --arg key "${public[$i]}" \
			'.[$file].publicKeys | index($key) != null' <<<"$rules" >/dev/null; then
			allowed=true
		fi
		decrypted=false
		if "$age" --decrypt --identity "${keys[$i]}" "$file" >/dev/null 2>/dev/null; then
			decrypted=true
		fi
		if [[ $allowed != "$decrypted" ]]; then
			echo "FAIL ${hosts[$i]}: $name (expected decrypt=$allowed)" >&2
			exit 1
		fi
	done
	if [[ -n $before ]]; then
		old=$("$age" --decrypt --identity "${keys[0]}" "$before/$name" | sha256sum)
		new=$("$age" --decrypt --identity "${keys[0]}" "$file" | sha256sum)
		[[ $old == "$new" ]] || {
			echo "Changed plaintext: $name" >&2
			exit 1
		}
	fi
done
printf 'PASS: rules, host permissions and full decryption matrix (%s files)\n' "$(jq length <<<"$files")"
if [[ -n $before ]]; then
	echo 'PASS: plaintext unchanged'
fi
