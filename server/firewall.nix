{ config, pkgs, ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      30419 # for visit badge
    ];
    allowedUDPPorts = [
      53
      80
      443
    ];
  };
}
