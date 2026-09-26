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
The default download is at most 100 MB per node, with a 10-second request
timeout and a 5-second connection timeout. Results show single-connection Mbps.
Fresh tests select the fastest node; cached results cycle through the ranking.
Results are cached for 600 seconds for the same filter and download URL.

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
SPEED="$XDIR/speed_test.json"

FILTER="${1-${XS_FILTER-Japan}}"
MAX_AGE=600
BASE_PORT=24100
TEST_URL="${XS_TEST_URL:-https://speed.cloudflare.com/__down?bytes=100000000}"
TIMEOUT=10
SCOPE="${XS_SYSTEMD_SCOPE:-user}"

case "$SCOPE" in
user | system) ;;
*)
	echo "xs: invalid systemd scope '$SCOPE'" >&2
	exit 1
	;;
esac

tmp=""
xray_pid=""
curl_pid=""

stop_probe() {
	local pid
	for pid in "$curl_pid" "$xray_pid"; do
		if [ -n "$pid" ]; then
			kill "$pid" 2>/dev/null || true
			wait "$pid" 2>/dev/null || true
		fi
	done
	curl_pid=""
	xray_pid=""
}

cleanup() {
	stop_probe
	[ -z "$tmp" ] || rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

port_open() {
	(exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

probe() {
	local file=$1 port=$2 conf=$3 attempt ready=0 status=0
	local curl_args=()
	if port_open "$port"; then
		echo "xs: skipping $file: port $port is occupied" >&2
		return
	fi
	xray -c "$conf" >"$tmp/xray.log" 2>&1 &
	xray_pid=$!
	for ((attempt = 0; attempt < 50; attempt++)); do
		kill -0 "$xray_pid" 2>/dev/null || break
		if port_open "$port"; then
			ready=1
			break
		fi
		sleep 0.1
	done
	if [ "$ready" -eq 0 ] || ! kill -0 "$xray_pid" 2>/dev/null; then
		echo "xs: skipping $file: Xray did not start" >&2
		stop_probe
		return
	fi

	if [[ "$TEST_URL" == https://speed.cloudflare.com/* ]]; then
		curl_args+=(--referer 'https://speed.cloudflare.com/')
	fi
	curl -q -s -o /dev/null --connect-timeout 5 --max-time "$TIMEOUT" \
		--noproxy '' --socks5-hostname "127.0.0.1:$port" \
		-w '%{http_code} %{speed_download} %{size_download} %{time_total} %{time_starttransfer}' \
		"${curl_args[@]}" --url "$TEST_URL" >"$tmp/metrics" &
	curl_pid=$!
	wait "$curl_pid" || status=$?
	curl_pid=""
	stop_probe
	if ! jq -Rne --arg file "$file" --argjson status "$status" '
    (input | split(" ") | map(tonumber)) as $m |
    select($m[0] == 200 and $m[1] > 0 and $m[2] > 0 and
      ($status == 0 or ($status == 28 and ($m[3] - $m[4]) >= 1))) |
    {file: $file, bytes_per_second: $m[1], bytes: $m[2], seconds: $m[3]}
  ' <"$tmp/metrics"; then
		local http bytes
		read -r http _ bytes _ <"$tmp/metrics" || true
		echo "xs: skipping $file: no valid download sample (HTTP ${http:-000}, bytes ${bytes:-0}, curl $status)" >&2
	fi
}

files=()
while IFS= read -r -d '' f; do
	name=${f##*/}
	[[ "$name" == *"$FILTER"* ]] && files+=("$name")
done < <(find "$SUBS" -maxdepth 1 -type f -name '*.json' -print0 | sort -z)
[ "${#files[@]}" -gt 0 ] || {
	echo "xs: no config matching '$FILTER' in $SUBS" >&2
	exit 1
}
file_list=$(jq -nc --args '$ARGS.positional' -- "${files[@]}")

speed_test() {
	local i=0 f port
	tmp=$(mktemp -d "$XDIR/.xs.XXXXXXXX")
	echo "xs: testing ${#files[@]} '$FILTER' configs (up to ${TIMEOUT}s each)..." >&2

	for f in "${files[@]}"; do
		port=$((BASE_PORT + i))
		echo "xs: downloading through $f..." >&2
		if jq -e --argjson port "$port" '{
      log: {loglevel: "error"},
      inbounds: [{listen: "127.0.0.1", port: $port, protocol: "socks",
                  settings: {auth: "noauth", udp: false}}],
      outbounds: [first(.outbounds[] | select(.tag == "proxy")) // .outbounds[0]]
    } | select(.outbounds[0] != null)' "$SUBS/$f" >"$tmp/$i.json"; then
			probe "$f" "$port" "$tmp/$i.json" >"$tmp/$i.res"
		else
			echo "xs: skipping $f: invalid node config" >&2
		fi
		i=$((i + 1))
	done

	shopt -s nullglob
	local results=("$tmp"/*.res)
	jq -n --arg filter "$FILTER" --arg url "$TEST_URL" '
    {version: 1, filter: $filter, url: $url,
     results: ([inputs] | sort_by([-.bytes_per_second, .file]))}
  ' "${results[@]}" </dev/null >"$tmp/cache.json"
	jq -e '.results | length > 0' "$tmp/cache.json" >/dev/null || {
		echo "xs: no config passed the speed test" >&2
		exit 1
	}
	mv "$tmp/cache.json" "$SPEED"
}

cache_valid() {
	[ -f "$SPEED" ] || return 1
	local age
	age=$(($(date +%s) - $(stat -c %Y "$SPEED")))
	[ "$age" -ge 0 ] && [ "$age" -lt "$MAX_AGE" ] || return 1
	jq -e --arg filter "$FILTER" --arg url "$TEST_URL" --argjson files "$file_list" '
    .version == 1 and .filter == $filter and .url == $url and
    (.results | type == "array" and length > 0 and all(.[];
      (.file as $file | $files | index($file) != null) and
      (.bytes_per_second | type == "number" and . > 0) and
      (.bytes | type == "number" and . > 0) and
      (.seconds | type == "number" and . > 0)))
  ' "$SPEED" >/dev/null 2>&1
}

tested=0
if ! cache_valid; then
	speed_test
	tested=1
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
ln -sfn "$SUBS/$sel" "$CFG"
if [ "$SCOPE" = system ]; then
	sudo systemctl restart xray.service
else
	systemctl --user restart xray.service
fi
printf 'xs: %s (%.2f Mbps)\n' "$sel" "$(jq -r --arg f "$sel" 'first(.results[] | select(.file == $f)).bytes_per_second * 8 / 1000000' "$SPEED")"
