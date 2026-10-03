{ config, lib, ... }:
{
  options.antares.proxy = {
    enable = lib.mkEnableOption "outbound proxy environment";
    httpUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:1081";
    };
    socksUrl = lib.mkOption {
      type = lib.types.str;
      default = "socks5://127.0.0.1:1080";
    };
  };
  config.assertions = [
    {
      assertion =
        !config.antares.proxy.enable
        || (config.antares.xray.enable or false)
        || (config.services.xray.enable or false);
      message = "The local proxy environment requires Xray; disable antares.proxy.enable for direct access.";
    }
  ];
}
