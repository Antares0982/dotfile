{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.programs.steam.enable) {
    environment.systemPackages = [
      pkgs.steamcmd
      pkgs.steam-run
    ];

    programs.steam = {
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };

  };
}
