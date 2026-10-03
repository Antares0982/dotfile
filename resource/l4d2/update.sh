set -euo pipefail
exec 9>"$HOME/update.lock"
flock -n 9
mkdir -p "$HOME/serverfiles"
log="$HOME/steam-update.log"

run_steam() {
  if ! timeout 90m "$@" >"$log" 2>&1; then
    cat "$log"
    return 1
  fi
  cat "$log"
  ! grep -Eq 'ERROR!|Error!' "$log" &&
    grep -q "Success! App '222860' fully installed" "$log" &&
    test -x "$HOME/serverfiles/srcds_linux"
}

install_game() {
  local -a args=(+force_install_dir "$HOME/serverfiles" +login anonymous)
  if run_steam "$@" "${args[@]}" +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit; then
    return 0
  fi
  if grep -q 'Invalid platform' "$log"; then
    run_steam "$@" "${args[@]}" +@sSteamCmdForcePlatformType windows +app_update 222860 \
      +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit
  else
    return 1
  fi
}

touch "$HOME/.update-incomplete"
if ! install_game steamcmd; then
  export http_proxy=http://127.0.0.1:1081
  export https_proxy="$http_proxy"
  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$http_proxy"
  install_game steam-run env LD_PRELOAD=libproxychains4.so \
    PROXYCHAINS_CONF_FILE="$PROXY_CONFIG" "$HOME/.local/share/Steam/steamcmd.sh" -tcp
fi
mkdir -p "$HOME/.steam/sdk32"
ln -sfn "$HOME/.local/share/Steam/linux32/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"
rm "$HOME/.update-incomplete"
