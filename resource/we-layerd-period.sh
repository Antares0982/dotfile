select_config() {
	case "$1" in
	0[0-5]) printf '%s\n' night.toml ;;
	0[6-9] | 1[0-8]) printf '%s\n' config.toml ;;
	19 | 2[0-3]) printf '%s\n' evening.toml ;;
	*) return 1 ;;
	esac
}

wallpaper_override() {
	local socket=${NIRI_SOCKET:?}
	printf '%s/we-layerd-%s.toml\n' "${XDG_RUNTIME_DIR:?}" "${socket##*/}"
}

wallpaper_config() {
	local override selected
	override=$(wallpaper_override) || return
	if [[ -f "$override" ]]; then
		printf '%s\n' "$override"
	else
		selected=$(select_config "$2") || return
		printf '%s/%s\n' "$1" "$selected"
	fi
}
