{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common/agenix.nix
    ../common/packages.nix
  ];
}
