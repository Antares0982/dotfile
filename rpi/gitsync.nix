{
  config,
  pkgs,
  lib,
  ...
}:
{
  systemd.timers."nix-git-sync" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "nix-git-sync.service";
    };
  };

  systemd.services."nix-git-sync" = {
    script = ''
      export PATH=$PATH:/run/current-system/sw/bin
      set -eu
      cd /home/git/Nix.git
      ${pkgs.git}/bin/git pull
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "git";
    };
  };
}
