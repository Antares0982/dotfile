{ config, lib, ... }:
{
  imports = [ ../modules/nixos/monitor.nix ];
  config = lib.mkIf config.services.telegram-output-monitor-bot.enable {
    services.telegram-output-monitor-bot.environmentFile = config.age.secrets.monitorCfgAntaresPc.path;
    age.secrets.monitorCfgAntaresPc = {
      file = ../secrets/monitor-cfg-antares-pc.age;
      owner = "antares";
      group = "users";
      mode = "440";
    };
  };
}
