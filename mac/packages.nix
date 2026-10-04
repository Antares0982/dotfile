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
    codex
    cmake
    opencode
    renewal
  ];
}
