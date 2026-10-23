#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
formatter=$(nix build --offline --no-write-lock-file --impure --no-link --print-out-paths --expr '
  let
    flake = builtins.getFlake "git+file://${builtins.getEnv "PWD"}?dir=hosts/nixos";
    system = flake.nixosConfigurations.nixos;
  in system.pkgs.writeShellScript "nixtreefmt" system.config.programs.zsh.shellAliases.nixtreefmt
')
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cd "$scratch"
printf '{ a = 1; }\n' >unchanged.nix
printf '{a=1;}\n' >'needs formatting.nix'
[[ $("$formatter") == './needs formatting.nix' ]]
cmp unchanged.nix 'needs formatting.nix'
[[ -z $("$formatter") ]]
printf '{ broken = ; }\n' >broken.nix
cp broken.nix original.txt
if "$formatter" >output.txt 2>error.txt; then
	exit 1
fi
[[ ! -s output.txt && -s error.txt ]]
cmp broken.nix original.txt
echo 'nixtreefmt checks passed.'
