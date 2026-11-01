{ lib }:
[
  {
    name = "wsl-host";
    module = { };
    check =
      c:
      c.networking.hostName == "wsl"
      && c.wsl.wslConf.network.hostname == "wsl"
      && c.environment.variables.NIX_DOT_FILES == "${c.users.users.antares.home}/Nix"
      && c.age.identityPaths == [ "/etc/ssh/agenix" ];
  }
  {
    name = "git-sign-unlock-on";
    module = { };
    check =
      c:
      let
        secret = c.age.secrets.gitSignPassphrase;
        service = c.systemd.services.git-sign-unlock;
        trigger = c.systemd.user.services.git-sign-unlock;
      in
      builtins.attrNames c.age.secrets == [ "gitSignPassphrase" ]
      && secret.owner == "root"
      && secret.group == "root"
      && secret.mode == "0400"
      && c.programs.ssh.startAgent
      && service.serviceConfig.User == "root"
      && service.environment.SSH_AUTH_SOCK == "/run/user/${toString c.users.users.antares.uid}/ssh-agent"
      && service.environment.SSH_ASKPASS_REQUIRE == "force"
      && service.wantedBy == [ ]
      && trigger.unitConfig.ConditionUser == "antares"
      && trigger.after == [ "ssh-agent.service" ]
      && trigger.requires == [ "ssh-agent.service" ]
      && trigger.partOf == [ "ssh-agent.service" ]
      &&
        trigger.wantedBy == [
          "default.target"
          "ssh-agent.service"
        ];
  }
  {
    name = "git-sign-unlock-off";
    module.antares.gitSignUnlock.enable = lib.mkForce false;
    check =
      c:
      !(c.systemd.services ? git-sign-unlock)
      && !(c.systemd.user.services ? git-sign-unlock)
      && c.age.secrets == { }
      && c.programs.ssh.startAgent
      && c.users.users ? antares;
  }
  {
    name = "git-sign-unlock-dependency";
    module.programs.ssh.startAgent = lib.mkForce false;
    check = c: true;
    valid = false;
  }
]
