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
  systemd.user.services.trilug = {
    Unit = {
      Description = "Tri-LUG";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 10;
    };

    Service = {
      WorkingDirectory = "${userenvs.home}/tri-lug";
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
