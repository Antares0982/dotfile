#!/usr/bin/env bash
# Fetch the L4D2 8-player-campaign plugin (l4d2multislots) into the running
# dedicated server's SourceMod tree. Paths are hardcoded; no arguments.
#
# Run as root, AFTER the l4d2 service has started at least once (steamcmd must
# have downloaded the game and Nix must have installed SourceMod).
#
# MetaMod:Source / SourceMod / l4dtoolz are managed by Nix (common/l4d2) and are
# NOT touched here. The 8-player campaign stack:
#   l4dtoolz       (Nix)  -> raises the human slot cap    (sv_maxplayers 8)
#   l4d2multislots (here) -> 8 survivor slots in coop/campaign
# Left4DHooks is NOT required for this setup.
#
# Source: https://github.com/rikka0w0/rikkal4d2 (ships the compiled .smx +
# gamedata). Pulls from master so the gamedata matches the current game build.
set -euo pipefail

REF="master"
BASE="https://raw.githubusercontent.com/rikka0w0/rikkal4d2/${REF}/addons/sourcemod"
GAME="/var/lib/l4d2/server/left4dead2"
SM="${GAME}/addons/sourcemod"

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run as root (needs chown to the l4d2 user)." >&2
  exit 1
fi

if [ ! -d "${GAME}/addons" ]; then
  echo "error: ${GAME}/addons not found." >&2
  echo "       Start the l4d2 service once so steamcmd downloads the game first." >&2
  exit 1
fi

mkdir -p "${SM}/plugins" "${SM}/gamedata"

echo "Downloading l4d2multislots (plugin + gamedata)..."
curl -fsSL "${BASE}/plugins/l4d2multislots.smx"  -o "${SM}/plugins/l4d2multislots.smx"
curl -fsSL "${BASE}/gamedata/l4d2multislots.txt" -o "${SM}/gamedata/l4d2multislots.txt"

echo "Fixing ownership..."
chown l4d2:l4d2 "${SM}/plugins/l4d2multislots.smx" "${SM}/gamedata/l4d2multislots.txt"

echo "Done. Restart the server to load it:"
echo "  systemctl restart l4d2"
