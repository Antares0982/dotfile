set -u
PATH=$PATH:/run/current-system/sw/bin
sleep 5
"$PULL_ALL"
if [ -d "$HOME/.config/google-chrome-no-proxy" ]; then
	rm -rf "$HOME/.config/google-chrome-no-proxy"
fi
if [ -d "$HOME/.config/google-chrome" ]; then
	cp -r "$HOME/.config/google-chrome" "$HOME/.config/google-chrome-no-proxy"
fi
for file in "$HOME/Downloads/"*; do
	if [[ "$file" == "$HOME/Downloads/"*.torrent ]]; then
		echo "Removing torrent file: $file"
		rm -f "$file"
	fi
done
