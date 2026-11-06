{ config, lib, ... }:
{
  options.antares.autostart.enable = lib.mkEnableOption "desktop startup script";
}
