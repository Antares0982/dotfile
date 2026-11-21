{ config, lib, ... }:
let
  proxy = config.antares.proxy;
  environment = {
    http_proxy = proxy.httpUrl;
    https_proxy = proxy.httpUrl;
    all_proxy = proxy.socksUrl;
  };
in
{
  config = lib.mkIf proxy.exportEnvironment {
    environment.variables = environment;
    launchd.daemons.nix-daemon.environment = environment;
  };
}
