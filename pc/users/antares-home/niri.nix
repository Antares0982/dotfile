{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  niri = "${osConfig.programs.niri.package}/bin/niri";
  layout = pkgs.replaceVars ../../../resource/niri-startup.py {
    inherit niri;
    kitty = "${pkgs.kitty}/bin/kitty";
    chrome = "${pkgs.google-chrome}/bin/google-chrome";
    telegram = lib.getExe pkgs.telegram-desktop;
  };
  qbit = pkgs.replaceVars ../../../resource/qbittorrent-startup.py {
    qbittorrent = "${pkgs.qbittorrent}/bin/qbittorrent";
    gdbus = "${pkgs.glib}/bin/gdbus";
  };
  session = {
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
    Requisite = [ "graphical-session.target" ];
    ConditionEnvironment = "WAYLAND_DISPLAY";
  };
in
{
  config = lib.mkIf osConfig.antares.desktop.enable {
    xdg.configFile."niri/config.kdl".source = pkgs.replaceVars ../../../resource/niri.kdl {
      startup = "${pkgs.python3}/bin/python3";
      startupScript = layout;
      DEFAULT_AUDIO_SINK = null;
      DEFAULT_AUDIO_SOURCE = null;
    };

    home.activation.backupNiri = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      file=${lib.escapeShellArg "${config.xdg.configHome}/niri/config.kdl"}
      if [[ -f "$file" && ! -L "$file" ]]; then
        run ${pkgs.coreutils}/bin/mv --backup=numbered "$file" "$file.before-home-manager"
      fi
    '';

    home.activation.migrateNiriServices =
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ]
        ''
          export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
          if ${pkgs.systemd}/bin/systemctl --user -q is-active graphical-session.target; then
            run ${pkgs.systemd}/bin/systemctl --user stop \
              'app-niri-waybar-*.scope' \
              'app-niri-kdeconnect\x2dindicator-*.scope' \
              'app-niri-lxqt\x2dpolicykit\x2dagent-*.scope'
          fi
        '';

    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        targets = [ "graphical-session.target" ];
      };
    };

    systemd.user.services = {
      mako = {
        Unit = session // {
          Description = "Desktop notifications";
        };
        Service = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${pkgs.mako}/bin/mako";
          ExecReload = "${pkgs.mako}/bin/makoctl reload";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      kdeconnect-indicator = {
        Unit = session // {
          Description = "KDE Connect tray";
        };
        Service = {
          ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      lxqt-policykit-agent = {
        Unit = session // {
          Description = "Desktop authentication agent";
        };
        Service = {
          ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      qbittorrent = {
        Unit = session // {
          Description = "qBittorrent tray";
          Wants = [ "waybar.service" ];
          After = session.After ++ [ "waybar.service" ];
        };
        Service = {
          ExecStart = "${pkgs.python3}/bin/python3 ${qbit}";
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 120;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
