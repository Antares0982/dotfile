{
  config,
  pkgs,
  lib,
  ...
}:
{
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#00af00";
  };
  antares.gitSignUnlock.enable = true;
  programs.ssh.startAgent = true;
  environment.variables.NIX_DOT_FILES = "${config.users.users.antares.home}/Nix";
  age.identityPaths = [ "/etc/ssh/agenix" ];
  wsl.enable = true;
  programs.direnv.enable = false;
  nixpkgs.config.allowUnfree = true;
  imports = [

    ./git-sign-unlock.nix
    ./network.nix
    ./packages.nix
    ./user.nix
  ]
  ++ [
    ../common/env.nix
    ../common/git-sign.nix
    ../common/nix.nix
    ../common/nix-zshell.nix
    ../common/sudo.nix
    ../common/time.nix
    ../common/zsh.nix
  ];
  system.stateVersion = "25.05";
}
