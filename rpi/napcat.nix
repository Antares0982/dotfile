{
  lib,
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
  qrPython = pkgs.python3.withPackages (ps: [
    ps.qrcode
    ps.pypng
    ps.requests
  ]);
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
  options.services.napcat.enable = lib.mkEnableOption "NapCat with watchdog and restart timer";
  config = lib.mkIf (config.services.napcat.enable) {

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

    systemd.services.napcat-login-qr = lib.mkIf config.services.telegram-output-monitor-bot.enable {
      description = "Send NapCat login QR codes to Telegram";
      wantedBy = [ "multi-user.target" ];
      environment = lib.optionalAttrs (config.antares.monitor.proxy != null) {
        https_proxy = config.antares.monitor.proxy;
      };
      restartTriggers = [ config.age.secrets.monitorCfgAntaresRpi.file ];
      script = ''
        set -o pipefail
        ${pkgs.systemd}/bin/journalctl --boot --follow --no-tail --since='2 minutes ago' \
          _SYSTEMD_UNIT=napcat.service --grep='^二维码解码URL: ' --output=json --output-fields=MESSAGE \
          | ${qrPython}/bin/python3 ${./napcat_login_qr.py}
      '';
      serviceConfig = {
        DynamicUser = true;
        SupplementaryGroups = [ "systemd-journal" ];
        ProtectHome = true;
        EnvironmentFile = config.services.telegram-output-monitor-bot.environmentFile;
        RuntimeDirectory = "napcat-login-qr";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "restart";
        Restart = "always";
        RestartSec = "3s";
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

    age.secrets.napcatEnv = {
      file = ../secrets/napcat-env.age;
      owner = "napcat";
      group = "users";
      mode = "400";
    };
  };
}
