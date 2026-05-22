{
  config,
  pkgs,
  lib,
  pkgs-old,
  ...
}:
let
  runnerUser = "ssrjsonrunner";
  commonEnvs = import ../common/shellEnv.nix;
  ranged = map toString (lib.range 1 10);
  genAttrs' = pkgs-old.lib.genAttrs';
in
{
  systemd.services =
    (genAttrs' ranged (i: {
      name = "ssrjson-runner-${i}";
      value = {
        script = ''
          export PATH=$PATH:${commonEnvs.sysBin}
          export http_proxy=http://127.0.0.1:1081
          export https_proxy=http://127.0.0.1:1081
          set -eu
          export HOME=/home/${runnerUser}/runner-${i}
          mkdir -p $HOME
          cd $HOME
          bash ${pkgs.github-runner}/bin/run.sh
        '';
        serviceConfig.User = runnerUser;
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
      };
    }))
    // (genAttrs' ranged (i: {
      name = "restart-ssrjson-runner-${i}";
      value = {
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl restart ssrjson-runner-${i}";
        };
      };
    }));

  systemd.timers = genAttrs' ranged (i: {
    name = "restart-ssrjson-runner-${i}";
    value = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
        Unit = "restart-ssrjson-runner-${i}.service";
      };
    };
  });

  users.users.${runnerUser} = {
    home = "/home/${runnerUser}";
  };
}
