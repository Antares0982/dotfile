{ config, pkgs, ... }:
{
  networking = {
    hostName = "nixos";
    # networkmanager.enable = true;
    firewall = {
      enable = false;
    };
  };
}
