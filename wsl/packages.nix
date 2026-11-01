{
  config,
  lib,
  pkgs,
  inputs,
  agenix,
  ...
}:
let
  renewal = inputs.renewal.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = with pkgs; [
    cheat
    codex
    imagemagick
    renewal
    agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
