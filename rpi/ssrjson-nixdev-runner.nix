{
  config,
  pkgs,
  lib,
  ...
}:
let
  runnerUser = "ssrjsonnixdev";
  commonEnvs = import ../common/shellEnv.nix;
in
{
  systemd.services.ssrjson-nixdev-runner = {
    script = ''
      export PATH=$PATH:${commonEnvs.sysBin}
      export http_proxy=http://127.0.0.1:1081
      export https_proxy=http://127.0.0.1:1081
      set -eu
      cd /home/${runnerUser}
      bash ${pkgs.github-runner}/bin/run.sh
    '';
    serviceConfig.User = runnerUser;
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.services.restart-ssrjson-nixdev-runner = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart ssrjson-nixdev-runner";
    };
  };

  systemd.timers.restart-ssrjson-nixdev-runner = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
      Unit = "restart-ssrjson-nixdev-runner.service";
    };
  };
}
