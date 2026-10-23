set -euo pipefail

usage() {
	cat <<'EOF'
Usage: xs [FILTER]
       xs -- FILTER
       xs --help

Select Xray nodes by a case-sensitive, literal filename substring.
FILTER overrides XS_FILTER; the default is Japan. An empty filter matches all.

Examples:
  xs               Test Japan nodes, or use XS_FILTER
  xs Hong          Test filenames containing Hong
  xs ''            Test all nodes
  xs '[JP]*'       Match the literal characters [JP]*
  xs -- -Japan     Match a substring beginning with -

Nodes are tested sequentially through private Xray SOCKS proxies.
Each node gets a 3-second quick sample; the top three get a 5-second final
sample. Downloads are at most 100 MB each. Results show single-connection Mbps.
Fresh tests select the fastest node; cached results cycle through the ranking.
Results are cached in the user cache for 600 seconds, keyed by node contents,
filter, URL and test parameters. Only final-tested nodes enter the ranking.

Environment:
  XS_FILTER          Default filename substring (Japan)
  XS_TEST_URL        Download URL (Cloudflare __down?bytes=100000000)
                     Custom URLs determine their own download size.
  XRAY_CONF_DIR      Xray directory (XDG_CONFIG_HOME/xray or ~/.config/xray)
  XS_CONFIG_PATH     Active config link (XRAY_CONF_DIR/config.json)
  XS_SYSTEMD_SCOPE   user (default) or system (restart through sudo)
EOF
}

case "${1-}" in
--help)
	[ "$#" -eq 1 ] || {
		usage >&2
		exit 2
	}
	usage
	exit 0
	;;
--) shift ;;
-*)
	usage >&2
	exit 2
	;;
esac
[ "$#" -le 1 ] || {
	usage >&2
	exit 2
}

XDIR="${XRAY_CONF_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/xray}"
SUBS="$XDIR/subscriptions"
CFG="${XS_CONFIG_PATH:-$XDIR/config.json}"

FILTER="${1-${XS_FILTER-Japan}}"
SCOPE="${XS_SYSTEMD_SCOPE:-user}"

case "$SCOPE" in
user | system) ;;
*)
	echo "xs: invalid systemd scope '$SCOPE'" >&2
	exit 1
	;;
esac

tmp=$(mktemp -d)
speed_pid=""
cleanup() {
	if [ -n "$speed_pid" ]; then
		kill "$speed_pid" 2>/dev/null || true
		wait "$speed_pid" 2>/dev/null || true
	fi
	rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
SPEED="$tmp/results.json"
xray-speed-test -- "$FILTER" >"$SPEED" &
speed_pid=$!
wait "$speed_pid"
speed_pid=""
tested=1
if jq -e '.cached == true' "$SPEED" >/dev/null; then
	tested=0
fi

names=()
mapfile -d '' -t names < <(jq -j '.results[].file + "\u0000"' "$SPEED")
[ "${#names[@]}" -gt 0 ] || {
	echo "xs: no config passed the speed test" >&2
	exit 1
}

idx=0
if [ "$tested" -eq 0 ]; then
	cur=""
	[ -L "$CFG" ] && cur=$(basename -- "$(readlink "$CFG")")
	for j in "${!names[@]}"; do
		if [ "${names[$j]}" = "$cur" ]; then
			idx=$(((j + 1) % ${#names[@]}))
			break
		fi
	done
fi

sel="${names[$idx]}"
[[ "$sel" != */* && "$sel" != active.json && -f "$SUBS/$sel" && ! -L "$SUBS/$sel" ]] || {
	echo "xs: selected node is no longer available" >&2
	exit 1
}
ln -sfn "$SUBS/$sel" "$CFG"
if [ "$SCOPE" = system ]; then
	sudo systemctl restart xray.service
else
	systemctl --user restart xray.service
fi
printf 'xs: %s (%.2f Mbps)\n' "$sel" "$(jq -r --arg f "$sel" 'first(.results[] | select(.file == $f)).bytes_per_second * 8 / 1000000' "$SPEED")"
