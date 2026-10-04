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
    pinentry-curses
    renewal
  ];
}
