{ config, lib, ... }:
{
  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 443 ];
}
