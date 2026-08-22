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
    ./wait-online.nix
    ./xdg-mime.nix
    ./xray.nix
  ];
  programs.home-manager.enable = true;
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };
  home = {
    stateVersion = "24.05";
    inherit (envs) username;
    homeDirectory = envs.userhome;
  };
}
