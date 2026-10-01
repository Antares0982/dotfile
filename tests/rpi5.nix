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
]
