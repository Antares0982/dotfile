{ config, lib, ... }:
{
  imports = [ ../../modules/nixos/monitor.nix ];
  config = lib.mkIf config.services.telegram-output-monitor-bot.enable {
    services.telegram-output-monitor-bot.environmentFile = config.age.secrets.monitorCfgAlice.path;
    age.secrets.monitorCfgAlice = {
      file = ../../secrets/monitor-cfg-alice.age;
      owner = "alice";
      group = "users";
      mode = "440";
    };
  };
}
