{ config, pkgs, ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [
      53
      80
      443
    ];
  };
}
