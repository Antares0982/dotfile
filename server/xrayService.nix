{
  config,
  pkgs,
  myXray,
  ...
}:
{
  services.xray = {
    package = myXray;
    enable = true;
    settingsFile = "/var/xray/config.json";
  };
}
