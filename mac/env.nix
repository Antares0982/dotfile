{ lib, config, pkgs, ... }:
let
  nix-zshell = pkgs.callPackage ../packages/nix-zshell.nix { };
in
{
  options.antares.nixShell.enable = lib.mkEnableOption "Nix Zsh build shell";
  config = lib.mkIf (config.antares.nixShell.enable) {

  environment.variables = {
    NIX_BUILD_SHELL = "${nix-zshell}/bin/nix-zshell";
  };

  };
}
