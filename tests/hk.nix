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
  {
    name = "xray-off";
    module = { lib, ... }: { services.xray.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? xray) && c.users.users ? alice;
  }
  {
    name = "web-dependency";
    module = { lib, ... }: { services.nginx.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "acme-dependency";
    module = { lib, ... }: { antares.acme.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
]
