{
  config,
  pkgs,
  napcat,
  ...
}:
let
  napcatWrapped = pkgs.writeShellApplication {
    name = "napcat-wrapped";
    runtimeInputs = [ napcat ];
    text = ''
      exec NapCat /home/napcat -q "$QQ_ID"
    '';
  };
  pyenv = pkgs.python3.withPackages (ps: with ps; [ websockets ]);
  napcatWatchdog = pkgs.writeShellApplication {
    name = "napcat-watchdog";
    runtimeInputs = [
      pyenv
      pkgs.systemd
    ];
    text = ''
      exec python3 ${./napcat-watchdog/napcat_watchdog.py}
    '';
  };
in
{
  users.users.napcat = {
    isNormalUser = true;
    home = "/home/napcat";
    description = "napcat service user";
    useDefaultShell = true;
  };

  systemd.services.napcat = {
    description = "NapCat QQ";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "napcat";
      ExecStart = "${napcatWrapped}/bin/napcat-wrapped";
      Restart = "on-failure";
      RestartSec = "10s";
      EnvironmentFile = config.age.secrets.napcatEnv.path;
    };
  };

  # NapCat does not re-login after QQ kicks the session: it stays alive with
  # `online: false`, so systemd's Restart= never fires. The watchdog reads the
  # OneBot WS for bot_offline / heartbeat status.online / get_status and
  # restarts the unit (rate limited) when the bot goes offline.
  systemd.services.napcat-watchdog = {
    description = "NapCat offline watchdog";
    after = [
      "network.target"
      "napcat.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Runs as root: it only opens a loopback WS, but needs systemctl restart.
      ExecStart = "${napcatWatchdog}/bin/napcat-watchdog";
      Restart = "always";
      RestartSec = "30s";
    };
  };

  systemd.services.napcat-restart = {
    description = "Restart NapCat QQ";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart napcat.service";
    };
  };

  systemd.timers.napcat-restart = {
    description = "Daily 05:11 restart of NapCat QQ";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:11:00";
      # No Persistent: catching up a missed 05:11 would restart a NapCat that
      # just came up with the machine, for nothing.
      Persistent = false;
    };
  };
}
