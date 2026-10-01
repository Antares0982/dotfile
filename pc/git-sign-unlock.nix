{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.users.users.antares;
  enabled = config.antares.gitSignUnlock.enable && config.antares.desktop.enable;
  askpass = pkgs.writeShellScript "git-sign-askpass" ''
    exec ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.age.secrets.gitSignPassphrase.path}
  '';
in
{
  options.antares.gitSignUnlock.enable = lib.mkEnableOption "Git signing key unlock at desktop startup";

  config = lib.mkIf enabled {
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
      description = "Unlock Git signing key";
      environment = {
        SSH_AUTH_SOCK = "/run/user/${toString user.uid}/ssh-agent";
        SSH_ASKPASS = toString askpass;
        SSH_ASKPASS_REQUIRE = "force";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${config.programs.ssh.package}/bin/ssh-add ${lib.escapeShellArg "${user.home}/.ssh/github_sign"}";
        StandardInput = "null";
        TimeoutStartSec = 15;
        LimitCORE = 0;
      };
    };

    home-manager.users.antares.systemd.user.services.git-sign-unlock = {
      Unit = {
        Description = "Load Git signing key for niri";
        After = [
          "niri.service"
          "ssh-agent.service"
        ];
        Requires = [ "ssh-agent.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/run/wrappers/bin/sudo -n ${config.systemd.package}/bin/systemctl start git-sign-unlock.service";
      };
      Install.WantedBy = [ "niri.service" ];
    };
  };
}
