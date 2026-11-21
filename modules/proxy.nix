{ config, lib, ... }:
{
  options.antares.proxy = {
    enable = lib.mkEnableOption "shared Mihomo proxy";
    insideGFW = lib.mkEnableOption "transparent dual-stack routing and fail-closed egress";
    lan = lib.mkEnableOption "home LAN proxy and WebUI access";
    exportEnvironment = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.bool;
      default = config.antares.proxy.enable && config.antares.proxy.insideGFW;
    };
    httpUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString config.antares.mihomo.port}";
    };
    socksUrl = lib.mkOption {
      type = lib.types.str;
      default = "socks5h://127.0.0.1:${toString config.antares.mihomo.port}";
    };
  };
}
