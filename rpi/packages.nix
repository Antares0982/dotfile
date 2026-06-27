{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = with pkgs; [
    clang-tools
    pinentry-curses
  ];
}
