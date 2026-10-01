{ config, lib, ... }:
{
  imports = [ ../modules/nixos/monitor.nix ];
  config = lib.mkIf config.services.telegram-output-monitor-bot.enable {
    services.telegram-output-monitor-bot.environmentFile = config.age.secrets.monitorCfgAntaresRpi.path;
    age.secrets.monitorCfgAntaresRpi = {
      file = ../secrets/monitor-cfg-antares-rpi.age;
      owner = "antares";
      group = "users";
      mode = "440";
    };
  };
}
