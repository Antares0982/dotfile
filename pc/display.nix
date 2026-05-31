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
  };

  environment = {
    systemPackages = with pkgs; [
      gvfs
      xwayland-satellite
    ];
    sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
