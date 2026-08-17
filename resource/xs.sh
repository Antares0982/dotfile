set -euo pipefail

XDIR="${XDG_CONFIG_HOME:-$HOME/.config}/xray"
SUBS="$XDIR/subscriptions"
CFG="$XDIR/config.json"
SPEED="$XDIR/speed_test.json"

FILTER="${XS_FILTER:-Japan}"
MAX_AGE=600
BASE_PORT=24100
TEST_URL="${XS_TEST_URL:-https://www.gstatic.com/generate_204}"
TIMEOUT=5

# Boot one xray on a private socks port, time one real request through it.
probe() {
  local file=$1 port=$2 conf=$3 pid t
  xray -c "$conf" >/dev/null 2>&1 &
  pid=$!
  sleep 0.7
  t=$(curl -s -o /dev/null --max-time "$TIMEOUT" -w '%{time_total}' \
    --socks5-hostname "127.0.0.1:$port" "$TEST_URL") || t=""
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [ -n "$t" ]; then
    jq -nc --arg file "$(basename "$file")" --argjson latency "$t" \
      '{file: $file, latency: $latency}'
  fi
}

tmp=""
trap '[ -z "$tmp" ] || rm -rf "$tmp"' EXIT

speed_test() {
  local files=() i=0 f port
  mapfile -t files < <(find "$SUBS" -maxdepth 1 -type f -name "*$FILTER*.json" | sort)
  [ "${#files[@]}" -gt 0 ] || { echo "xs: no config matching '$FILTER' in $SUBS" >&2; exit 1; }

  tmp=$(mktemp -d)
  echo "xs: testing ${#files[@]} '$FILTER' configs..." >&2

  for f in "${files[@]}"; do
    port=$((BASE_PORT + i))
    jq --argjson port "$port" '{
      log: {loglevel: "error"},
      inbounds: [{listen: "127.0.0.1", port: $port, protocol: "socks",
                  settings: {auth: "noauth", udp: false}}],
      outbounds: [first(.outbounds[] | select(.tag == "proxy")) // .outbounds[0]]
    }' "$f" >"$tmp/$i.json"
    probe "$f" "$port" "$tmp/$i.json" >"$tmp/$i.res" &
    i=$((i + 1))
  done
  wait

  jq -s 'sort_by(.latency)' "$tmp"/*.res >"$SPEED"
}

tested=0
if [ ! -f "$SPEED" ] || [ $(($(date +%s) - $(stat -c %Y "$SPEED"))) -ge "$MAX_AGE" ]; then
  speed_test
  tested=1
fi

names=()
mapfile -t names < <(jq -r '.[].file' "$SPEED")
[ "${#names[@]}" -gt 0 ] || { echo "xs: no config passed the speed test" >&2; exit 1; }

idx=0
if [ "$tested" -eq 0 ]; then
  cur=""
  [ -L "$CFG" ] && cur=$(basename "$(readlink "$CFG")")
  for j in "${!names[@]}"; do
    if [ "${names[$j]}" = "$cur" ]; then
      idx=$(((j + 1) % ${#names[@]}))
      break
    fi
  done
fi

sel="${names[$idx]}"
ln -sfn "$SUBS/$sel" "$CFG"
systemctl --user restart xray.service
printf 'xs: %s (%.3fs)\n' "$sel" "$(jq -r --arg f "$sel" 'first(.[] | select(.file == $f)).latency' "$SPEED")"
