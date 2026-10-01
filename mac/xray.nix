{
  lib,
  config,
  pkgs,
  myXray,
  ...
}:
{
  options.antares.xray.enable = lib.mkEnableOption "Xray launchd service";
  config = lib.mkIf (config.antares.xray.enable) {

    launchd.daemons.xray = {
      script = ''
        ${myXray}/bin/xray -c /Users/antares/NixApp/xray-config.json
      '';
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };
    };

  };
}
