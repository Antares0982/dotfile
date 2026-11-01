{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.users.users.antares;
  askpass = pkgs.writeShellScript "git-sign-askpass" ''
    exec ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.age.secrets.gitSignPassphrase.path}
  '';
in
{
  options.antares.gitSignUnlock.enable = lib.mkEnableOption "Git key unlock in WSL user sessions";

  config = lib.mkIf config.antares.gitSignUnlock.enable {
    assertions = [
      {
        assertion = config.programs.ssh.startAgent;
        message = "Git signing key unlock requires programs.ssh.startAgent.";
      }
    ];

    age.secrets.gitSignPassphrase = {
      file = ../secrets/github-sign-passphrase.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.git-sign-unlock = {
      description = "Unlock Git signing and GitHub push keys";
      environment = {
        SSH_AUTH_SOCK = "/run/user/${toString user.uid}/ssh-agent";
        SSH_ASKPASS = toString askpass;
        SSH_ASKPASS_REQUIRE = "force";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${config.programs.ssh.package}/bin/ssh-add ${lib.escapeShellArg "${user.home}/.ssh/github_sign"} ${lib.escapeShellArg "${user.home}/.ssh/github_push"}";
        StandardInput = "null";
        TimeoutStartSec = 15;
        LimitCORE = 0;
      };
    };

    systemd.user.services.git-sign-unlock = {
      description = "Load Git keys into the WSL SSH agent";
      wantedBy = [
        "default.target"
        "ssh-agent.service"
      ];
      after = [ "ssh-agent.service" ];
      requires = [ "ssh-agent.service" ];
      partOf = [ "ssh-agent.service" ];
      unitConfig.ConditionUser = user.name;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/run/wrappers/bin/sudo -n ${config.systemd.package}/bin/systemctl start git-sign-unlock.service";
      };
    };
  };
}
