{
  config,
  lib,
  pkgs,
  myXray,
  ...
}:
{
  services.xray = lib.mkIf config.services.xray.enable {
    package = myXray;
    settingsFile = "/var/xray/config.json";
  };
}
