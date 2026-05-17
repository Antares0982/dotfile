#!/usr/bin/env bash
if [ -z $1 ]; then
  notify-send Error "need argument"
  echo "need argument"
  exit 1
fi

if [ -z "${XRAY_CONFIG_PATH+x}" ]; then
  source $HOME/.zshenv
fi

if [ -z "${XRAY_CONFIG_PATH+x}" ]; then
  notify-send Error "env XRAY_CONFIG_PATH does not exist"
  exit 1
fi

if [ ! -e "$XRAY_CONFIG_PATH" ]; then
  notify-send Error "config file does not exist: $XRAY_CONFIG_PATH"
  exit 1
fi

file="$@"

if [ ! -e "$file" ]; then
  notify-send Error "does not exist: $file"
  exit 1
fi

rm -f "$XRAY_CONFIG_PATH"
ln -s "$file" "$XRAY_CONFIG_PATH"
systemctl --user restart xray.service
notify-send Success "xray config changed to $file"
