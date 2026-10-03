{
  lib,
  config,
  pkgs,
  ...
}:
let
  steamWorkshop = (import ../packages { inherit pkgs; }).steam-workshop-ts;
  steamWorkshopWithKey = pkgs.writeShellScriptBin "steam-workshop-ts" ''
    STEAM_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.age.secrets.steamApiKey.path})" || exit 1
    export STEAM_API_KEY
    exec ${lib.getExe steamWorkshop} "$@"
  '';
in
{
  config = lib.mkIf (config.programs.steam.enable) {
    age.secrets.steamApiKey = {
      file = ../secrets/steam-api-key.age;
      owner = "antares";
      group = "users";
      mode = "0400";
    };

    environment.systemPackages = [
      pkgs.steamcmd
      pkgs.steam-run
      steamWorkshopWithKey
    ];

    programs.steam = {
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };

  };
}
