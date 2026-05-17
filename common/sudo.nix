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
    }
    // (lib.optionalAttrs currentDevice.useProxy {
      extraConfig = ''
        Defaults env_keep += "http_proxy https_proxy"
      '';
    });
    pam.services.su.requireWheel = true;
  };
}
