{
  config,
  pkgs,
  lib,
  ...
}:
let
  userenvs = import ./_userenv.nix;
in
{
  systemd.user.services.alice = {
    Unit = {
      Description = "Maid Alice";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 10;
    };

    Service = {
      WorkingDirectory = "${userenvs.home}/alice";
      ExecStart = ''
        ${pkgs.nix}/bin/nix develop -c python main.py
      '';
      Environment = [
        "PATH=${userenvs.sysBin}"
      ];
      Restart = "on-failure";
      RestartSec = 5;
      StartLimitBurst = 3;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
