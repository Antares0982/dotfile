#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_CASE=zsh-base nix eval --offline --no-write-lock-file --impure --json --expr '
  let
    root = builtins.getEnv "PWD";
    flake = builtins.getFlake "git+file://${root}?dir=hosts/wsl";
    system = flake.nixosConfigurations.wsl;
  in import ./tests/features.nix {
    inherit root;
    host = "wsl";
    flake.nixosConfigurations.wsl = system // {
      extendModules = _: throw "Unchanged cases must reuse the host evaluation";
    };
  }
'
