{ config, lib, ... }:
{
  options.antares.proxy = {
    enable = lib.mkEnableOption "shared Mihomo proxy";
    insideGFW = lib.mkEnableOption "transparent dual-stack routing and fail-closed egress";
    lan = lib.mkEnableOption "home LAN proxy and WebUI access";
    clientAddress = lib.mkOption {
      type = lib.types.strMatching "127(\\.[0-9]{1,3}){3}";
      default = "127.0.0.1";
      description = "IPv4 loopback address for local proxy, API and bandwidth clients.";
    };
    exportEnvironment = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.bool;
      default = config.antares.proxy.enable && config.antares.proxy.insideGFW;
    };
    httpUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${config.antares.proxy.clientAddress}:${toString config.antares.mihomo.port}";
    };
    socksUrl = lib.mkOption {
      type = lib.types.str;
      default = "socks5h://${config.antares.proxy.clientAddress}:${toString config.antares.mihomo.port}";
    };
  };
}
