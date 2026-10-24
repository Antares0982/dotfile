{
  config,
  pkgs,
  lib,
  ...
}:
{
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#005faf";
  };
  wsl.enable = true;
  nixpkgs.config.allowUnfree = true;
  imports = [

    ./network.nix
    ./packages.nix
    ./user.nix
  ]
  ++ [
    ../common/env.nix
    ../common/nix.nix
    ../common/nix-zshell.nix
    ../common/sudo.nix
    ../common/time.nix
    ../common/zsh.nix
  ];
  system.stateVersion = "25.05";
}
