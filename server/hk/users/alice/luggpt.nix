{
  config,
  pkgs,
  lib,
  ...
}:
let
  userenvs = import ./_userenv.nix;
  cp = "${pkgs.coreutils}/bin/cp";
  alice = "${userenvs.home}/alice";
  nix = "${pkgs.nix}/bin/nix";
in
{
  systemd.user.services.luggpt = {
    Unit = {
      Description = "GPT bot for Linux User Group";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 10;
    };

    Service = {
      WorkingDirectory = "${userenvs.home}/luggpt";
      ExecStart = ''
        ${userenvs.sysBin}/bash start.sh
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
