{ config, lib, ... }:
{
  options.antares.autostart.enable = lib.mkEnableOption "desktop startup script";
  config.assertions = [
    {
      assertion = !config.antares.autostart.enable || config.antares.xray.enable;
      message = "Desktop autostart invokes Xray tools and requires antares.xray.enable.";
    }
  ];
}
