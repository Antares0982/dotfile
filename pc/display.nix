{ config, pkgs, ... }:
{
  programs = {
    niri.enable = true;
    xwayland.enable = true;
    kdeconnect = {
      enable = true;
      package = pkgs.kdePackages.kdeconnect-kde;
    };
    regreet = {
      enable = true;
      extraCss = ''
        window.background {
          background-image: url("file:///boot/background.png");
          background-size: cover;
          background-position: center;
        }
      '';
    };
  };

  services = {
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
    ];
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  security.polkit.enable = true;
}
