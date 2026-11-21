{ config, lib, ... }:
{
  networking.hostName = "wsl";
  networking.firewall.enable = config.antares.proxy.enable && config.antares.proxy.lan;
  wsl.wslConf.network.generateResolvConf = lib.mkIf config.antares.proxy.exportEnvironment false;
}
