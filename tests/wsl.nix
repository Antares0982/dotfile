{ lib }:
[
  {
    name = "windows-shell-on";
    module = { };
    check =
      c:
      c.antares.windowsShell.enable
      && c.system.build ? windowsShell
      && c.environment.etc ? "windows-shell/env.zsh"
      && c.environment.etc ? "windows-shell/interactive.zsh"
      && c.environment.etc ? "windows-shell/starship.toml"
      && c.environment.etc ? "windows-shell/starship-git.toml";
  }
  {
    name = "windows-shell-off";
    module.antares.windowsShell.enable = lib.mkForce false;
    check =
      c:
      !(c.system.build ? windowsShell)
      && !(c.environment.etc ? "windows-shell/env.zsh")
      && !(c.environment.etc ? "windows-shell/interactive.zsh")
      && !(c.environment.etc ? "windows-shell/starship.toml")
      && !(c.environment.etc ? "windows-shell/starship-git.toml")
      && c.programs.zsh.enable
      && c.programs.zoxide.enable
      && c.users.users ? antares;
  }
  {
    name = "windows-shell-without-starship";
    module.antares.starship.enable = lib.mkForce false;
    check =
      c:
      c.environment.etc ? "windows-shell/env.zsh"
      && !(c.environment.etc ? "windows-shell/starship.toml")
      && !(c.environment.etc ? "windows-shell/starship-git.toml");
  }
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
