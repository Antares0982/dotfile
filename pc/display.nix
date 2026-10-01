{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.antares.desktop.enable = lib.mkEnableOption "desktop session and integration";
  config = lib.mkIf (config.antares.desktop.enable) {

    programs = {
      niri.enable = true;
      xwayland.enable = true;
      kdeconnect = {
        enable = true;
        package = pkgs.kdePackages.kdeconnect-kde;
      };
    };

    services = {
      displayManager.regreet = {
        enable = true;
        extraCss = ''
          window.background {
            background-image: url("file:///boot/background.png");
            background-size: cover;
            background-position: center;
          }
        '';
      };
      accounts-daemon.enable = true;
      gnome.gcr-ssh-agent.enable = false;
      greetd = {
        enable = true;
        settings = {
          default_session = {
            # command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session -r";
            user = "greeter";
          };
        };
      };
      gvfs.enable = true; # for kdeconnect
      udisks2.enable = true;
    };

    environment = {
      systemPackages = with pkgs; [
        gvfs
        xwayland-satellite
        fuzzel
        grim
        kdePackages.kio-fuse
        kdePackages.kio-extras
        kitty
        lxqt.lxqt-policykit
        mako
        pavucontrol
        slurp
        swaylock
        swaybg
        thunar
        thunar-archive-plugin
        waybar
        wl-clipboard
        xdg-terminal-exec
      ];
      sessionVariables.NIXOS_OZONE_WL = "1";
    };

    security.polkit.enable = true;

    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };
  };
}
