{ config, pkgs, ... }:
{
  imports = [
    ./boot.nix
    ./hardware-configuration.nix
  ];
}
