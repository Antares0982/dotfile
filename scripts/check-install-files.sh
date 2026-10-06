#!/usr/bin/env bash
set -euo pipefail
if (($# != 1)); then
	echo "Usage: $0 EXTRA_FILES_ROOT" >&2
	exit 2
fi
root=$1
for path in "$root" "$root/etc" "$root/etc/ssh"; do
	[[ ! -L $path && $(stat -c %a "$path") == 755 ]] || {
		echo "FAIL: expected directory mode 0755: $path" >&2
		exit 1
	}
	test -d "$path"
done
key=$root/etc/ssh/agenix
[[ -f $key && ! -L $key && $(stat -c %a "$key") == 600 ]]
ssh-keygen -y -P '' -f "$key" >/dev/null
for key in "$root"/etc/ssh/ssh_host_*_key; do
	[[ -f $key && ! -L $key && $(stat -c %a "$key") == 600 ]]
done
echo 'PASS: installation directory and private-key permissions'
