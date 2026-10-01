{ config, pkgs, ... }:
{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall = {
      enable = true;
    };
    hosts = {
      "43.129.210.213" = [
        "chr.fan"
        "alyr.dev"
      ];
    };
  };
}
