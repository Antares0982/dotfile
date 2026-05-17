{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = with pkgs; [
    cheat
    direnv
    imagemagick
  ];
}
