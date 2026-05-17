{
  config,
  pkgs,
  myXray,
  ...
}:
{
  launchd.daemons.xray = {
    script = ''
      ${myXray}/bin/xray -c /Users/antares/NixApp/xray-config.json
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
