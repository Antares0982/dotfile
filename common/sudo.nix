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
      extraConfig = lib.concatStringsSep "\n" (
        lib.optional currentDevice.useProxy ''
          Defaults env_keep += "http_proxy https_proxy"
        ''
        ++ lib.optional currentDevice.rpi ''
          hermes ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart xray
          hermes ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart xray-sub
          hermes ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl start xray-sub
        ''
      );
    };
    pam.services.su.requireWheel = true;
  };
}
