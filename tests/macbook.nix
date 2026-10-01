{ lib }: [
  {
    name = "xray-off";
    module = { lib, ... }: {
      antares.xray.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.launchd.daemons ? xray)
      && !(c.launchd.daemons.nix-daemon.environment ? http_proxy)
      && !(c.launchd.daemons.nix-daemon.environment ? all_proxy);
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { antares.xray.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
]
