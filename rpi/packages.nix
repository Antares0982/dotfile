{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  renewal = inputs.renewal.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = with pkgs; [
    clang-tools
    cmake
    gcc
    gdb
    nix-output-monitor
    pinentry-curses
    renewal
  ];
}
