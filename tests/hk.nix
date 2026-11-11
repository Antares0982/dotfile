{ lib }: [
  {
    name = "mihomo-headless";
    module = { };
    check =
      c:
      c.services.mihomo.enable
      && c.services.mihomo.webui == null
      && !(c.systemd.services.mihomo.environment ? SAFE_PATHS)
      && c.antares.mihomo.singapore
      && c.antares.mihomo.settings.mixed-port == 1081
      && !c.antares.mihomo.settings.allow-lan
      && c.antares.mihomo.settings.bind-address == "127.0.0.1"
      && c.antares.mihomo.settings.external-controller == "127.0.0.1:17900"
      && lib.all (entry: entry.listen == "127.0.0.1") c.antares.mihomo.settings.listeners
      && lib.all (port: !(lib.elem port c.networking.firewall.allowedTCPPorts)) [
        1081
        1082
        1083
        17900
        17901
      ]
      &&
        (lib.findFirst (g: g.name == "GLOBAL") { } c.antares.mihomo.policy.proxy-groups).default-selected
        == "SG"
      && c.age.secrets.mihomoSubscription.owner == "root"
      && c.age.secrets.mihomoSubscription.mode == "0400"
      && lib.any (p: lib.getName p == "mihomo-tools") c.environment.systemPackages
      && lib.any (p: lib.getName p == "clashtui") c.environment.systemPackages;
  }
  {
    name = "server-base";
    module = { };
    check =
      c:
      c.services.fail2ban.enable
      && c.services.sysstat.enable
      && c.services.sysstat.collect-frequency == "*:00/01"
      && c.services.sysstat.collect-args == "1 1"
      && c.networking.firewall.enable;
  }
  {
    name = "forgejo";
    module = { };
    check =
      c:
      c.systemd.services.forgejo.serviceConfig.User == "git"
      && c.systemd.services.forgejo.serviceConfig.Group == "git"
      && c.users.users.git.isSystemUser
      && !c.users.users.git.isNormalUser
      && c.users.users.git.home == "/var/lib/forgejo"
      && c.users.users.git.group == "git"
      && c.users.users.git.openssh.authorizedKeys.keys == [ ]
      && c.users.users.git.hashedPasswordFile == null
      && c.services.forgejo.database.type == "sqlite3"
      && c.services.forgejo.settings.server.ROOT_URL == "https://git.chr.fan/"
      && c.services.forgejo.settings.server.HTTP_ADDR == "127.0.0.1"
      && c.services.forgejo.settings.server.LANDING_PAGE == "login"
      && c.services.forgejo.settings.server.SSH_DOMAIN == "git.chr.fan"
      && c.services.forgejo.settings.server.SSH_PORT == 22
      && !c.services.forgejo.settings.server.START_SSH_SERVER
      && c.services.forgejo.settings.service.DISABLE_REGISTRATION
      && c.services.forgejo.settings.service.REQUIRE_SIGNIN_VIEW
      && c.services.forgejo.settings.session.COOKIE_SECURE
      && !(lib.elem 3000 c.networking.firewall.allowedTCPPorts)
      && c.services.nginx.virtualHosts."git.chr.fan".forceSSL
      && c.services.nginx.virtualHosts."git.chr.fan".locations."/".proxyPass == "http://127.0.0.1:3000"
      && c.security.acme.certs ? "git.chr.fan";
  }
  {
    name = "forgejo-off";
    module = { lib, ... }: { services.forgejo.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? forgejo)
      && !(c.systemd.services ? forgejo-secrets)
      && !(c.users.users ? git)
      && !(c.users.groups ? git)
      && !(c.services.nginx.virtualHosts ? "git.chr.fan")
      && !(c.security.acme.certs ? "git.chr.fan")
      && !(lib.any (p: lib.getName p == "forgejo-lts") c.environment.systemPackages)
      && c.users.users ? antares
      && c.users.users ? alice
      && c.services.nginx.enable
      && c.services.openssh.enable;
  }
  {
    name = "forgejo-web-dependency";
    module = { lib, ... }: {
      antares.messaging.enable = lib.mkForce false;
      antares.blog.enable = lib.mkForce false;
      services.nginx.enable = lib.mkForce false;
    };
    check = c: true;
    valid = false;
  }
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
    name = "mihomo-off";
    module = { lib, ... }: { antares.mihomo.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? mihomo)
      && !(c.systemd.services ? mihomo-config)
      && !(c.age.secrets ? mihomoSubscription)
      && c.users.users ? alice;
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
      services.forgejo.enable = lib.mkForce false;
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
  {
    name = "mysql-off";
    module = { lib, ... }: {
      services.mysql.enable = lib.mkForce false;
      antares.blog.metrics.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.systemd.services ? mysql)
      && !c.services.mysqlBackup.enable
      && !(c.systemd.services ? mysql-backup)
      && c.services.nginx.virtualHosts ? "chr.fan";
  }
  {
    name = "mysql-dependency";
    module = { lib, ... }: { services.mysql.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "all-features-off";
    module = { lib, ... }: {
      antares.blog.enable = lib.mkForce false;
      antares.messaging.enable = lib.mkForce false;
      services.forgejo.enable = lib.mkForce false;
      antares.acme.enable = lib.mkForce false;
      security.acme.certs = lib.mkForce { };
      mailserver.enable = lib.mkForce false;
      services.mysql.enable = lib.mkForce false;
      services.nginx.enable = lib.mkForce false;
      antares.mihomo.enable = lib.mkForce false;
      services.rabbitmq.enable = lib.mkForce false;
      services.telegram-output-monitor-bot.enable = lib.mkForce false;
      services.antares-rpc-client.enable = lib.mkForce false;
    };
    check =
      c:
      c.users.users ? alice
      && !(c.users.users ? git)
      && !(c.users.groups ? git)
      &&
        builtins.attrNames c.age.secrets == [
          "password"
          "serverPassword"
        ]
      && builtins.attrNames c.home-manager.users.alice.systemd.user.services == [ "nix-gc" ];
  }
  {
    name = "acme-dns";
    module = { lib, ... }: { };
    check =
      c:
      lib.all (cert: cert.dnsProvider == "cloudflare" && cert.webroot == null) (
        builtins.attrValues c.security.acme.certs
      );
  }
]
