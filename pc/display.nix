{ config, pkgs, ... }:
{
  programs.niri.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

  programs.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session -r";
        user = "greeter";
      };
    };
  };

  services.gvfs.enable = true;
  environment.systemPackages = with pkgs; [
    gvfs
    xwayland-satellite
  ];

  programs.xwayland.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
