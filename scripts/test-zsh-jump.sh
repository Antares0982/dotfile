#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
nix eval --offline --no-write-lock-file --impure --raw --expr '
  let
    flake = builtins.getFlake "git+file://${builtins.getEnv "PWD"}?dir=hosts/nixos";
    pkgs = flake.nixosConfigurations.nixos.pkgs;
  in (pkgs.callPackage ./pc/users/antares-home/zsh.nix {}).programs.zsh.initContent
' >"$scratch/init.zsh"
zsh -f -s -- "$scratch" <<'ZSH'
set -e
scratch=$1
source "$scratch/init.zsh"
mkdir "$scratch/repo with spaces"
cd "$scratch"
zi() {
  filters=("$@")
  (( cancelled )) && return 130
  builtin cd -- "$scratch/repo with spaces"
}
_f() { launched=("$PWD" "$@"); }
for entry app in zn nvim zc codex zo opencode; do
  cancelled=0
  launched=()
  "$entry"
  [[ ${#filters} == 0 && $launched[1] == "$scratch/repo with spaces" && $launched[2] == "$app" ]]
  "$entry" 'repo with' spaces
  [[ ${#filters} == 2 && $filters[1] == 'repo with' && $filters[2] == spaces ]]
  builtin cd -- "$scratch"
  cancelled=1
  launched=()
  if "$entry"; then exit 1; else result=$?; fi
  [[ $result == 130 && ${#launched} == 0 && $PWD == "$scratch" ]]
done
print 'Zsh directory selection checks passed.'
ZSH
