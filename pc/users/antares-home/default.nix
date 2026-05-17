{
  config,
  pkgs,
  lib,
  myXray,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
in
{
  imports = [
    ./antares-rpc-client.nix
    ./autostart.nix
    ./env.nix
    # ./git_credential_refresher.nix
    ./jetbrains.nix
    ./monitor.nix
    ./wait-online.nix
    ./xray.nix
  ];
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  home.username = envs.username;
  home.homeDirectory = envs.userhome;
}
