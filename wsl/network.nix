{ config, pkgs, ... }:
{
  networking = {
    hostName = "wsl";
    # networkmanager.enable = true;
    firewall = {
      enable = false;
    };
  };
}
