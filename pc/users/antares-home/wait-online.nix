{
  config,
  pkgs,
  lib,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
  pkgs-def =
    pypkgs: with pypkgs; [
      systemd-python
    ];
  pyenv = pkgs.python313.withPackages pkgs-def;
in
{
  systemd.user.services.waitOnline = {
    Unit = {
      Description = "Wait until we're connected to the Internet";
      After = [ "network.target" ];
    };

    Service = {
      Type = "notify";
      ExecStart = ''
        ${pyenv}/bin/python check-online
      '';
      TimeoutStartSec = "infinity";
      WorkingDirectory = "${envs.envs.GITHUB_DIR}/wait-online";
      Environment = [
        "http_proxy=${envs.envs.http_proxy}"
        "https_proxy=${envs.envs.https_proxy}"
      ];
    };

    Install = {
      WantedBy = [ "network-online.target" ];
      Also = "wait-online-onresume.service";
    };
  };

  systemd.user.services.waitOnlineOnresume = {
    Unit = {
      Description = "Restart wait-online on resume";
      Before = [ "sleep.target" ];
      StopWhenUnneeded = "yes";
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStop = "${pkgs.systemd}/bin/systemctl --user try-restart wait-online.service";
      TimeoutStartSec = "infinity";
    };

    Install = {
      WantedBy = [ "sleep.target" ];
    };
  };
}
