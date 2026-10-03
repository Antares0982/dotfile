{
  config,
  lib,
  pkgs,
  we-layerd,
  ...
}:
let
  enabled = config.antares.desktop.enable && config.antares.wallpaper.enable;
  root = "/var/lib/we-layerd";
  format = pkgs.formats.toml { };
  binding = id: {
    wallpaper_id = id;
    source = "${root}/workshop/${id}";
  };
  common = {
    renderer = {
      assets_path = "${root}/assets";
      fps = 60;
      muted = true;
    };
    wallpapers =
      lib.genAttrs
        [
          "3759473977"
          "3657215414"
          "3545541611"
          "3780257889"
          "3222456142"
        ]
        (_: {
          muted = true;
        });
  };
  desktop =
    main: secondary:
    common
    // {
      outputs = {
        HDMI-A-5 = binding main;
        HDMI-A-1 = binding secondary;
      };
    };
  settings = {
    "config.toml" = desktop "3759473977" "3657215414";
    "evening.toml" = desktop "3545541611" "3780257889";
    "night.toml" = desktop "3222456142" "3780257889";
  };
  configs = lib.mapAttrs (name: value: format.generate "we-layerd-${name}" value) settings;
  configDir = pkgs.linkFarm "we-layerd-configs" (
    lib.mapAttrsToList (name: path: { inherit name path; }) configs
  );
  session = pkgs.writeShellScript "we-layerd-session" ''
    set -eu
    ${builtins.readFile ../resource/we-layerd-period.sh}
    case "$1" in
      run) ;;
      switch) ${pkgs.systemd}/bin/systemctl --user is-active --quiet we-layerd.service || exit 0 ;;
      *) exit 2 ;;
    esac
    selected=$(select_config "$(${pkgs.coreutils}/bin/date +%H)")
    exec ${we-layerd}/bin/we-layerd "$1" --config "${configDir}/$selected"
  '';
  loginConfig = format.generate "we-layerd-greeter.toml" {
    general.interactive = false;
    renderer = common.renderer // {
      source = "${root}/workshop/3482954869";
      cache_path = "/var/cache/we-layerd-greeter";
    };
  };
  greeter = pkgs.writeShellScript "we-layerd-greeter" ''
    ${we-layerd}/bin/we-layerd run --config ${loginConfig} &
    wallpaper_pid=$!
    cleanup() {
      kill "$wallpaper_pid" 2>/dev/null || true
      wait "$wallpaper_pid" 2>/dev/null || true
      ${config.programs.niri.package}/bin/niri msg action quit --skip-confirmation || true
    }
    trap cleanup EXIT
    trap 'exit 0' TERM INT
    ${lib.getExe config.services.displayManager.regreet.package}
  '';
  greeterNiri = pkgs.writeText "we-layerd-greeter.kdl" ''
    prefer-no-csd
    hotkey-overlay { skip-at-startup; }
    gestures { hot-corners { off; }; }
    layout {
      gaps 0
      background-color "#17202a"
      focus-ring { off; }
      border { off; }
      shadow { off; }
    }
    output "HDMI-A-5" {
      scale 1.25
      position x=1920 y=0
    }
    output "HDMI-A-1" {
      scale 1.0
      position x=0 y=0
    }
    window-rule {
      match app-id="^apps\\.regreet$"
      open-on-output "HDMI-A-5"
      open-fullscreen false
      open-maximized-to-edges true
    }
    environment {
      GTK_USE_PORTAL "0"
      GDK_DEBUG "no-portals"
    }
    spawn-at-startup "${greeter}"
  '';
in
{
  options.antares.wallpaper.enable = lib.mkEnableOption "scheduled desktop and login wallpapers";

  config = lib.mkIf enabled {
    home-manager.users.antares = {
      home.packages = [ we-layerd ];
      xdg.configFile = lib.mapAttrs' (
        name: source:
        lib.nameValuePair "we-layerd/${name}" {
          inherit source;
        }
      ) configs;
      systemd.user.services = {
        we-layerd = {
          Unit = {
            Description = "Scheduled Wallpaper Engine desktop";
            After = [ "niri.service" ];
            PartOf = [ "niri.service" ];
          };
          Service = {
            ExecStart = "${session} run";
            ExecReload = "${session} switch";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "niri.service" ];
        };
        we-layerd-switch = {
          Unit = {
            Description = "Select current wallpaper period";
            After = [ "we-layerd.service" ];
            PartOf = [ "niri.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${session} switch";
          };
        };
      };
      systemd.user.timers.we-layerd-switch = {
        Unit = {
          Description = "Switch wallpapers at midnight, 06:00 and 19:00";
          PartOf = [ "niri.service" ];
          After = [ "niri.service" ];
        };
        Timer = {
          OnCalendar = "*-*-* 00,06,19:00:00";
          OnClockChange = true;
          OnTimezoneChange = true;
          Persistent = true;
          AccuracySec = "1s";
        };
        Install.WantedBy = [ "niri.service" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${root} 0755 root root -"
      "d ${root}/workshop 0755 root root -"
      "d /var/cache/we-layerd-greeter 0700 greeter greeter -"
    ];
    environment.etc."greetd/we-layerd.toml".source = loginConfig;
    services.displayManager.regreet.extraCss = ''
      window.background {
        background-image: none;
        background-color: transparent;
      }
    '';
    services.greetd.settings.default_session.command =
      "${pkgs.dbus}/bin/dbus-run-session ${config.programs.niri.package}/bin/niri --config ${greeterNiri}";
  };
}
