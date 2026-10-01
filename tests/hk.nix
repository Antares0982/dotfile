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
  {
    name = "blog-off";
    module = { lib, ... }: { antares.blog.enable = lib.mkForce false; };
    check =
      c:
      !(c.services.nginx.virtualHosts ? "chr.fan")
      && !(c.services.nginx.virtualHosts ? "blog.chr.fan")
      && !(c.systemd.services ? site-metrics)
      && !(c.users.users ? site-metrics)
      && c.security.acme.certs ? "chr.fan"
      && c.mailserver.enable
      && c.services.mysql.enable
      && c.services.nginx.virtualHosts ? "tg.alyr.dev";
  }
  {
    name = "metrics-off";
    module = { lib, ... }: { antares.blog.metrics.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? site-metrics)
      && !(c.systemd.services ? site-metrics-init)
      && !(c.systemd.services ? site-metrics)
      && !(c.systemd.timers ? site-metrics)
      && !(c.services.nginx.virtualHosts."chr.fan".locations ? "= /api/views.json")
      && !(lib.elem "site_metrics" c.services.mysql.ensureDatabases)
      && c.services.mysqlBackup.enable
      && c.services.nginx.virtualHosts ? "chr.fan";
  }
]
