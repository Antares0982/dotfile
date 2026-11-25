{ lib }: [
  {
    name = "simple-moderation";
    module = { };
    check =
      c:
      c.services.simple-moderation.enable
      && c.services.simple-moderation.host == "127.0.0.1"
      && c.services.simple-moderation.port == 18765
      && c.services.simple-moderation.apiKeyFile == c.age.secrets.simpleModerationKey.path
      && c.age.secrets.simpleModerationKey.owner == "root"
      && c.age.secrets.simpleModerationKey.mode == "0400"
      && c.systemd.services.simple-moderation.serviceConfig.DynamicUser
      && builtins.elem "deepseek-api-key:${c.age.secrets.simpleModerationKey.path}" c.systemd.services.simple-moderation.serviceConfig.LoadCredential
      && builtins.elem "simple-moderation.service" c.systemd.services.qq-codex-agent.after
      && !(builtins.elem 18765 c.networking.firewall.allowedTCPPorts);
  }
  {
    name = "simple-moderation-off";
    module = { lib, ... }: { services.simple-moderation.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? simple-moderation)
      && !(c.age.secrets ? simpleModerationKey)
      && !(builtins.elem "simple-moderation.service" c.systemd.services.qq-codex-agent.after);
  }
  {
    name = "codex-auth";
    module = { };
    check =
      c:
      c.systemd.services ? codex-auth
      && c.systemd.services ? codex-login
      && builtins.elem "codex-auth-clients" c.users.users.agent.extraGroups
      && c.systemd.services.antares-agent.environment.ANTARES_AUTH_SOCKET == "/run/codex-auth/auth.sock"
      && !(c.age.secrets ? antaresAgentEnv);
  }
  {
    name = "codex-auth-off";
    module = { lib, ... }: {
      antares.agent.enable = lib.mkForce false;
      antares.qq.enable = lib.mkForce false;
    };
    check = c: !(c.systemd.services ? codex-auth) && !(c.users.users ? codex-auth);
  }
  {
    name = "actionrunner-off";
    module = { lib, ... }: {
      services.antares-runners.instances.actionrunner.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.users.users ? actionrunner)
      && !(c.systemd.services ? github-runner)
      && !(c.systemd.services ? restart-github-runner)
      && !(c.systemd.timers ? restart-github-runner);
  }
  {
    name = "runners";
    module = { };
    check =
      c:
      builtins.attrNames c.services.antares-runners.instances == [ "actionrunner" ]
      && c.users.users ? actionrunner
      && c.systemd.services ? github-runner
      && c.systemd.services ? restart-github-runner
      && c.systemd.timers ? restart-github-runner
      && lib.all (name: !(lib.hasInfix "ssrjson" name)) (
        builtins.attrNames c.users.users
        ++ builtins.attrNames c.systemd.services
        ++ builtins.attrNames c.systemd.timers
      );
  }
  {
    name = "runner-collision";
    module = { config, ... }: {
      services.antares-runners.instances.collision = {
        enable = true;
        user = "actionrunner";
        package = config.services.antares-runners.instances.actionrunner.package;
      };
    };
    check = c: true;
    valid = false;
  }
  {
    name = "monitor-off";
    module = { lib, ... }: { services.telegram-output-monitor-bot.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? telegram-output-monitor-bot)
      && !(c.systemd.services ? napcat-login-qr)
      && !(c.age.secrets ? monitorCfgAntaresRpi);
  }
  {
    name = "rpc-off";
    module = { lib, ... }: { services.antares-rpc-client.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? rpc-client-antares)
      && !(c.age.secrets ? rabbitClientCfgAntaresRpi)
      && c.users.users ? antares;
  }
  {
    name = "agent-off";
    module = { lib, ... }: { antares.agent.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? agent)
      && !(c.users.users ? agent-relay)
      && !(c.systemd.services ? antares-agent)
      && !(c.systemd.services ? antares-agent-relay)
      && !(c.systemd.services ? antares-agent-update)
      && !(c.systemd.generators ? antares-agent-mounts)
      && !(c.age.secrets ? antaresAgentEnv)
      && !(c.age.secrets ? agentRelayRabbitKey)
      && lib.all (r: !(lib.hasInfix "agent_work" r)) c.systemd.tmpfiles.rules
      && !(c.systemd.services ? mihomo-worker)
      && !(c.systemd.paths ? mihomo-worker)
      && !(c.systemd.services ? mihomo-agent-guide)
      && c.systemd.services ? mihomo;
  }
  {
    name = "napcat-login-qr";
    module = { };
    check =
      c:
      let
        unit = c.systemd.services.napcat-login-qr;
      in
      unit.serviceConfig.DynamicUser
      && builtins.elem "systemd-journal" unit.serviceConfig.SupplementaryGroups
      && unit.serviceConfig.EnvironmentFile == c.age.secrets.monitorCfgAntaresRpi.path
      && unit.environment.https_proxy == c.antares.monitor.proxy;
  }
  {
    name = "napcat-dependency";
    module = { lib, ... }: { services.napcat.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? napcat)
      && !(c.systemd.services ? napcat)
      && !(c.systemd.services ? napcat-watchdog)
      && !(c.systemd.services ? napcat-login-qr)
      && !(c.systemd.timers ? napcat-restart)
      && !(c.age.secrets ? napcatEnv);
    valid = false;
  }
  {
    name = "qq-relay-off";
    module = { lib, ... }: { services.qq-napcat-relay.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? qq-napcat-relay)
      && !(c.systemd.services ? qq-napcat-relay-restart)
      && !(c.systemd.timers ? qq-napcat-relay-restart)
      && !(c.age.secrets ? qqRelayRabbitKey)
      && c.age.secrets ? qqRelayEnv
      && c.systemd.services ? qq-codex-agent
      && c.users.users ? napcat;
  }
  {
    name = "qq-codex-config";
    module = { };
    check =
      c:
      c.services.qq-codex-agent.configFile == c.age.secrets.qqCodexAllowlist.path
      && builtins.elem "sysinit-reactivation.target" c.systemd.services.qq-codex-agent.partOf
      && builtins.elem "sysinit-reactivation.target" c.systemd.services.qq-codex-agent.after
      && c.services.qq-codex-agent.allowlistFile == null
      && c.age.secrets.qqCodexAllowlist.owner == "qq-codex-agent"
      && c.age.secrets.qqCodexAllowlist.mode == "0400"
      && builtins.elem "${c.age.secrets.qqCodexAllowlist.path}:/etc/qq-codex-private/config.toml" c.systemd.services.qq-codex-agent.serviceConfig.BindReadOnlyPaths
      && !(builtins.any (
        path: lib.hasSuffix ":/etc/qq-codex-private/allowlist.toml" path
      ) c.systemd.services.qq-codex-agent.serviceConfig.BindReadOnlyPaths)
      && builtins.elem c.age.secrets.qqCodexAllowlist.file c.systemd.services.qq-codex-agent.restartTriggers;
  }
  {
    name = "qq-codex-rcon";
    module = { };
    check =
      c:
      c.age.secrets.l4d2-rcon.owner == "qq-codex-agent"
      && c.age.secrets.l4d2-rcon.group == "qq-codex-agent"
      && c.age.secrets.l4d2-rcon.mode == "0400"
      &&
        c.systemd.services.qq-codex-agent.environment.L4D2_RCON_PASSWORD_FILE
        == "/etc/qq-codex-agent/l4d2-rcon"
      && builtins.elem "${c.age.secrets.l4d2-rcon.path}:/etc/qq-codex-agent/l4d2-rcon" c.systemd.services.qq-codex-agent.serviceConfig.BindReadOnlyPaths
      && builtins.elem c.age.secrets.l4d2-rcon.file c.systemd.services.qq-codex-agent.restartTriggers;
  }
  {
    name = "qq-codex-image-api";
    module = { };
    check =
      c:
      let
        secret = c.age.secrets.openaiPersonalApiKey;
        service = c.systemd.services.qq-codex-agent;
      in
      secret.owner == "qq-codex-agent"
      && secret.mode == "0400"
      && builtins.elem secret.file service.restartTriggers
      && (
        !(c.services.qq-codex-agent ? imageApiKeyFile)
        || builtins.elem "${secret.path}:/etc/qq-codex-private/image-api-key" service.serviceConfig.BindReadOnlyPaths
      );
  }
  {
    name = "qq-off";
    module = { lib, ... }: { antares.qq.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? napcat)
      && !(c.age.secrets ? openaiPersonalApiKey)
      && !(c.systemd.services ? napcat)
      && !(c.systemd.services ? napcat-login-qr)
      && !(c.systemd.services ? qq-napcat-relay)
      && !(c.systemd.services ? qq-codex-agent)
      && !(c.systemd.services ? simple-moderation)
      && !(c.age.secrets ? simpleModerationKey)
      && !(c.systemd.services ? qq-codex-auth)
      && !(c.systemd.services ? qq-codex-login)
      && !(c.age.secrets ? qqRelayEnv)
      && !(c.age.secrets ? qqCodexGhToken)
      && !(c.age.secrets ? l4d2-rcon)
      && !(c.age.secrets ? napcatEnv);
  }
  {
    name = "qq-codex-off";
    module = { lib, ... }: { antares.qq.codex.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? qq-codex-agent)
      && !(c.age.secrets ? openaiPersonalApiKey)
      && c.systemd.services ? codex-auth
      && c.systemd.services ? codex-login
      && !(c.systemd.services ? simple-moderation)
      && !(c.age.secrets ? simpleModerationKey)
      && !(c.systemd.services ? qq-codex-auth)
      && !(c.systemd.services ? qq-codex-login)
      && !(c.age.secrets ? qqCodexGhToken)
      && !(c.age.secrets ? l4d2-rcon)
      && c.age.secrets ? qqRelayEnv
      && c.systemd.services ? qq-napcat-relay;
  }
  {
    name = "mihomo-on";
    module = { };
    check =
      c:
      c.antares.proxy.enable
      && c.antares.proxy.lan
      && c.antares.mihomo.port == 1081
      &&
        map (entry: entry.port) c.antares.mihomo.settings.listeners == [
          1082
          1083
          17901
        ]
      && !(c.antares.mihomo.settings ? sub-rules)
      && (builtins.head c.antares.mihomo.settings.listeners).proxy == "GLOBAL"
      && c.antares.proxy.socksUrl == "socks5h://127.0.0.1:1081"
      && c.services.mihomo.enable
      && c.systemd.services.mihomo-worker.serviceConfig.DynamicUser
      && c.systemd.services.mihomo-worker.serviceConfig.User == "mihomo-worker"
      && c.systemd.services.mihomo-worker.serviceConfig.Group == "agent"
      && c.systemd.services.mihomo-worker.serviceConfig.NoNewPrivileges
      && c.systemd.services.mihomo-worker.serviceConfig.ProtectSystem == "strict"
      &&
        c.systemd.paths.mihomo-worker.pathConfig.DirectoryNotEmpty
        == "/home/agent/agent_work/.agent/mihomo/requests"
      && c.age.secrets.mihomoSubscription.owner == "root"
      && c.age.secrets.mihomoSubscription.mode == "0400"
      && lib.elem "mihomo.service" c.systemd.services.antares-agent.after;
  }
  {
    name = "mihomo-off";
    module = { lib, ... }: {
      antares.proxy.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.environment.variables ? http_proxy)
      && !(c.systemd.services.antares-agent.environment ? http_proxy)
      && !(lib.elem "mihomo.service" c.systemd.services.antares-agent.after)
      && !(c.systemd.services ? mihomo)
      && !(c.systemd.services ? mihomo-config)
      && !(c.systemd.services ? mihomo-worker)
      && !(c.systemd.paths ? mihomo-worker)
      && !(c.systemd.services ? mihomo-agent-guide)
      && !(c.age.secrets ? mihomoSubscription);
  }
  {
    name = "rabbitmq-off";
    module = { lib, ... }: { services.rabbitmq.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? rabbitmq) && !(c.users.users ? rabbitmq);
  }
  {
    name = "ssh-probe-off";
    module = { lib, ... }: { services.ssh-probe.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? ssh-probe) && c.services.openssh.enable;
  }
  {
    name = "git-server-off";
    module = { lib, ... }: { antares.gitServer.enable = lib.mkForce false; };
    check = c: !(c.users.users ? git) && c.users.users ? antares && c.services.openssh.enable;
  }
  {
    name = "runner-unit-collision";
    module = { config, ... }: {
      services.antares-runners.instances.collision = {
        enable = true;
        user = "collisionrunner";
        serviceName = "restart-github-runner";
        package = config.services.antares-runners.instances.actionrunner.package;
      };
    };
    check = c: true;
    valid = false;
  }
  {
    name = "all-features-off";
    module = { lib, ... }: {
      antares = {
        agent.enable = lib.mkForce false;
        qq.enable = lib.mkForce false;
        proxy.enable = lib.mkForce false;
        gitServer.enable = lib.mkForce false;
      };
      services.antares-runners.instances = lib.mkForce { };
      services.ssh-probe.enable = lib.mkForce false;
      services.telegram-output-monitor-bot.enable = lib.mkForce false;
      services.antares-rpc-client.enable = lib.mkForce false;
      services.rabbitmq.enable = lib.mkForce false;
    };
    check =
      c:
      c.users.users ? antares
      && !(c.users.users ? agent)
      && !(c.users.users ? napcat)
      && !(c.users.users ? actionrunner)
      && !(c.users.users ? git)
      &&
        builtins.attrNames c.age.secrets == [
          "password"
          "serverPassword"
        ];
  }
]
