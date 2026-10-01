{ lib }: [
  {
    name = "monitor-off";
    module = { lib, ... }: { services.telegram-output-monitor-bot.enable = lib.mkForce false; };
    check =
      c: !(c.systemd.services ? telegram-output-monitor-bot) && !(c.age.secrets ? monitorCfgAlice);
  }
  {
    name = "rpc-off";
    module = { lib, ... }: { services.antares-rpc-client.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.alice.systemd.user.services ? rpc-client)
      && !(c.age.secrets ? rabbitClientCfgAlice)
      && c.users.users ? alice;
  }
]
