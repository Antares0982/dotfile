{
  config,
  lib,
  currentDevice,
  ...
}:
{
  launchd.daemons.nix-daemon.environment = lib.attrsets.optionalAttrs currentDevice.useProxy {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
    all_proxy = "socks5://127.0.0.1:1080";
  };
}
