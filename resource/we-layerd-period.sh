select_config() {
	case "$1" in
	0[0-5]) printf '%s\n' night.toml ;;
	0[6-9] | 1[0-8]) printf '%s\n' config.toml ;;
	19 | 2[0-3]) printf '%s\n' evening.toml ;;
	*) return 1 ;;
	esac
}
