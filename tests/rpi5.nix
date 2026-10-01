{ lib }: [
  {
    name = "actionrunner-off";
    module = { lib, ... }: {
      services.antares-runners.instances.actionrunner.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.users.users ? actionrunner)
      && !(c.systemd.services ? github-runner)
      && !(c.systemd.services ? restart-github-runner)
      && !(c.systemd.timers ? restart-github-runner)
      && c.users.users ? ssrjsonrunner;
  }
  {
    name = "ssrjson-off";
    module = { lib, ... }: { services.antares-runners.instances.ssrjson.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? ssrjsonrunner)
      && lib.all (
        i:
        !(builtins.hasAttr "ssrjson-runner-${toString i}" c.systemd.services)
        && !(builtins.hasAttr "restart-ssrjson-runner-${toString i}" c.systemd.services)
        && !(builtins.hasAttr "restart-ssrjson-runner-${toString i}" c.systemd.timers)
      ) (lib.range 1 10)
      && c.systemd.services ? github-runner;
  }
  {
    name = "ssrjson-one";
    module = { lib, ... }: { services.antares-runners.instances.ssrjson.count = lib.mkForce 1; };
    check =
      c:
      c.systemd.services ? ssrjson-runner-1
      && !(c.systemd.services ? ssrjson-runner-2)
      && lib.hasInfix "/home/ssrjsonrunner/runner-1" c.systemd.services.ssrjson-runner-1.script;
  }
]
