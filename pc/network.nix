{ config, pkgs, ... }:
{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        } # KDE Connect
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        } # KDE Connect
      ];
    };
    hosts = {
      "43.129.210.213" = [
        "chr.fan"
        "alyr.dev"
      ];
    };
  };
}
