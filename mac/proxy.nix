{
  config,
  lib,
  currentDevice,
  ...
}:
{
  launchd.daemons.nix-daemon.environment = lib.mkIf config.antares.proxy.enable {
    http_proxy = config.antares.proxy.httpUrl;
    https_proxy = config.antares.proxy.httpUrl;
    all_proxy = config.antares.proxy.socksUrl;
  };
}
