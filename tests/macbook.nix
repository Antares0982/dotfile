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
  {
    name = "nix-shell-off";
    module = { lib, ... }: { antares.nixShell.enable = lib.mkForce false; };
    check = c: !(c.environment.variables ? NIX_BUILD_SHELL) && c.environment.variables ? NIX_DOT_FILES;
  }
  {
    name = "system-compiler-off";
    module = { lib, ... }: { antares.systemCompiler.enable = lib.mkForce false; };
    check = c: !(lib.hasInfix "system-cc-shims" c.environment.extraInit);
  }
]
