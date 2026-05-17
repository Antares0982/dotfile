{
  config,
  pkgs,
  lib,
  antares-monitor,
  ...
}:
let
  userenvs = import ./_userenv.nix;
in
{
  systemd.user.services.monitor = {
    Unit = {
      Description = "Logger Bot";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 10;
    };

    Service = {
      ExecStart = ''
        ${antares-monitor}/bin/monitor.py
      '';
      EnvironmentFile = userenvs.monitorCfgPath;
      Restart = "on-failure";
      RestartSec = 5;
      StartLimitBurst = 3;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
