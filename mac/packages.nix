{
  config,
  pkgs,
  inputs,
  ...
}:
let
  renewal = inputs.renewal.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  environment.systemPackages = with pkgs; [
    clang-tools
    codex
    cmake
    gcc
    gdb
    renewal
  ];
}
