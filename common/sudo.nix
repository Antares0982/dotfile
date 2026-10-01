{
  config,
  currentDevice,
  lib,
  ...
}:
{
  security = {
    sudo = {
      wheelNeedsPassword = false;
      extraConfig = lib.optionalString (config.antares.proxy.enable or currentDevice.useProxy) ''
        Defaults env_keep += "http_proxy https_proxy"
      '';
    };
    pam.services.su.requireWheel = true;
  };
}
