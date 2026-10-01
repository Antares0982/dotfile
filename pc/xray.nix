{ config, lib, ... }:
{
  options.antares.xray.enable = lib.mkEnableOption "Xray user service";
  config = lib.mkIf config.antares.xray.enable {
    networking.firewall.allowedTCPPortRanges = [
      {
        from = 1080;
        to = 1081;
      }
    ];
  };
}
