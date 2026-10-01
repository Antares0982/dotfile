{ config, lib, ... }:
{
  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [
    80
    443
  ];
  assertions = [
    {
      assertion = config.services.nginx.enable || config.services.nginx.virtualHosts == { };
      message = "Enabled web sites require services.nginx.enable.";
    }
  ];
}
