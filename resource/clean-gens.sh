#!/usr/bin/env bash
# clean-gens.sh — delete NixOS generations ABOVE the current one
# Use after rolling back to a stable generation to make it the boot default.
set -euo pipefail

PROFILE=/nix/var/nix/profiles/system

# Resolve current generation by matching /run/current-system against profile links.
# Using readlink on $PROFILE would give the *latest* generation, not the *running* one.
current_system=$(readlink -f /run/current-system)
current_gen=""
for link in "$PROFILE"-*-link; do
  if [[ "$(readlink -f "$link")" == "$current_system" ]]; then
    current_gen=$(basename "$link" | grep -oP '(?<=system-)\d+(?=-link)')
    break
  fi
done

if [[ -z "$current_gen" ]]; then
  echo "Error: could not match /run/current-system to any generation profile" >&2
  exit 1
fi

echo "Current generation: $current_gen"
echo ""

# Collect generation numbers above current by scanning symlinks directly.
# nix-env --list-generations requires sudo for the system profile, so we avoid it here.
to_delete_nums=()
for link in "$PROFILE"-*-link; do
  n=$(basename "$link" | grep -oP '(?<=system-)\d+(?=-link)')
  (( n > current_gen )) && to_delete_nums+=("$n")
done

# Sort numerically
IFS=$'\n' to_delete_nums=($(printf '%s\n' "${to_delete_nums[@]}" | sort -n)); unset IFS

if [[ ${#to_delete_nums[@]} -eq 0 ]]; then
  echo "No generations above $current_gen. Nothing to delete."
  exit 0
fi

# Display with dates from sudo nix-env --list-generations
echo "Generations to be deleted:"
echo "---"
sudo nix-env -p "$PROFILE" --list-generations \
  | awk -v nums=" ${to_delete_nums[*]} " 'index(nums, " "$1" ") > 0 {print "  " $0}'
echo "---"
echo ""

read -rp "Delete ${#to_delete_nums[@]} generation(s) listed above? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo "Deleting generations: ${to_delete_nums[*]}"
# The profile symlink may still point to a newer generation.
# Switch it to current first — nix-env refuses to delete the profile's active generation.
sudo nix-env -p "$PROFILE" --switch-generation "$current_gen"
sudo nix-env -p "$PROFILE" --delete-generations "${to_delete_nums[@]}"

echo ""
echo "Updating bootloader entries..."
sudo "$PROFILE/bin/switch-to-configuration" boot

echo ""
echo "Remaining generations:"
sudo nix-env -p "$PROFILE" --list-generations

echo ""
echo "Generation $current_gen is now the latest. Reboot to enter it by default."
