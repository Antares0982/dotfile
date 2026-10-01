{ lib, config, pkgs, ... }:
let
  nix-zshell = (import ../packages { inherit pkgs; }).nix-zshell;
in
{
  options.antares.nixShell.enable = lib.mkEnableOption "Nix Zsh build shell";
  config = lib.mkIf (config.antares.nixShell.enable) {

  environment.variables = {
    NIX_BUILD_SHELL = "${nix-zshell}/bin/nix-zshell";
  };

  };
}
