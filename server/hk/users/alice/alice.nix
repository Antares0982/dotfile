{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  userenvs = import ./_userenv.nix;
in
{
  config = lib.mkIf (osConfig.antares.messaging.enable && osConfig.antares.alice.enable) {

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
          "ANTARES_FILE_ROOT=/var/lib/agent-files"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        StartLimitBurst = 3;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  };
}
