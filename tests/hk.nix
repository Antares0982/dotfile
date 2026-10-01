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
  {
    name = "mail-off";
    module = { lib, ... }: { mailserver.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? postfix)
      && !(c.systemd.services ? dovecot2)
      && !(c.services.fail2ban.jails ? postfix-sasl)
      && !(c.services.fail2ban.jails ? dovecot)
      && !(c.age.secrets ? mailPasswordAntares)
      && !(c.age.secrets ? mailPasswordAlyr)
      && !(c.security.acme.certs ? "mail.alyr.dev")
      && c.security.acme.certs ? "chr.fan"
      && c.services.fail2ban.enable;
  }
  {
    name = "alice-off";
    module = { lib, ... }: { antares.alice.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.alice.systemd.user.services ? alice)
      && !(c.age.secrets ? aliceTelegramWebhookSecret)
      && c.users.users ? alice
      && c.home-manager.users.alice.systemd.user.services ? trilug;
  }
  {
    name = "trilug-off";
    module = { lib, ... }: { antares.trilug.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.alice.systemd.user.services ? trilug)
      && !(c.services.nginx.virtualHosts ? "tri-lug.chr.fan")
      && !(c.security.acme.certs ? "tri-lug.chr.fan")
      && c.users.users ? alice
      && c.home-manager.users.alice.systemd.user.services ? alice;
  }
  {
    name = "telegram-api-off";
    module = { lib, ... }: { services.telegram-bot-api.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? telegram-bot-api)
      && !(c.age.secrets ? telegramBotApiEnv)
      && c.users.users ? alice
      && c.services.nginx.virtualHosts ? "tg.alyr.dev";
  }
  {
    name = "agent-files-off";
    module = { lib, ... }: {
      antares.agentFiles.enable = lib.mkForce false;
      antares.alice.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.users.groups ? agent-files)
      && !(c.age.secrets ? agentFilesHtpasswd)
      && !(c.services.nginx.virtualHosts ? "tg.alyr.dev")
      && !(c.security.acme.certs ? "tg.alyr.dev")
      && !(lib.elem "agent-files" c.users.users.alice.extraGroups)
      && !(lib.elem "agent-files" (
        c.systemd.services.telegram-bot-api.serviceConfig.SupplementaryGroups or [ ]
      ))
      && c.services.nginx.enable;
  }
  {
    name = "agent-files-dependency";
    module = { lib, ... }: { antares.agentFiles.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "messaging-off";
    module = { lib, ... }: { antares.messaging.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.alice.systemd.user.services ? alice)
      && !(c.home-manager.users.alice.systemd.user.services ? trilug)
      && !(c.systemd.services ? telegram-bot-api)
      && !(c.services.nginx.virtualHosts ? "tg.alyr.dev")
      && !(c.age.secrets ? aliceTelegramWebhookSecret)
      && !(c.age.secrets ? telegramBotApiEnv)
      && !(c.users.groups ? agent-files)
      && c.users.users ? alice
      && c.home-manager.users.alice.systemd.user.services ? rpc-client
      && c.services.telegram-output-monitor-bot.enable;
  }
  {
    name = "web-off-mail-on";
    module = { lib, ... }: {
      antares.messaging.enable = lib.mkForce false;
      antares.blog.enable = lib.mkForce false;
      services.nginx.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.systemd.services ? nginx)
      && c.mailserver.enable
      && c.security.acme.certs ? "chr.fan"
      && c.users.groups ? nginx
      && !(lib.elem 80 c.networking.firewall.allowedTCPPorts)
      && !(lib.elem 443 c.networking.firewall.allowedTCPPorts);
  }
  {
    name = "rabbitmq-off";
    module = { lib, ... }: { services.rabbitmq.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? rabbitmq)
      && !(c.users.users ? rabbitmq)
      && !(c.age.secrets ? rabbitmqDefinitions)
      && !(lib.elem 5671 c.networking.firewall.allowedTCPPorts);
  }
]
