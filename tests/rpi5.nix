{ lib }: [
  {
    name = "codex-auth";
    module = { };
    check =
      c:
      c.systemd.services ? codex-auth
      && c.systemd.services ? codex-login
      && builtins.elem "codex-auth-clients" c.users.users.agent.extraGroups
      && c.systemd.services.antares-agent.environment.ANTARES_AUTH_SOCKET == "/run/codex-auth/auth.sock"
      && c.services.qq-codex-agent.authSocket == "/run/codex-auth/auth.sock"
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
      && !(c.systemd.timers ? restart-github-runner)
      && c.users.users ? ssrjsonrunner;
  }
  {
    name = "ssrjson-off";
    module = { lib, ... }: { services.antares-runners.instances.ssrjson.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? ssrjsonrunner)
      && lib.all (
        i:
        !(builtins.hasAttr "ssrjson-runner-${toString i}" c.systemd.services)
        && !(builtins.hasAttr "restart-ssrjson-runner-${toString i}" c.systemd.services)
        && !(builtins.hasAttr "restart-ssrjson-runner-${toString i}" c.systemd.timers)
      ) (lib.range 1 10)
      && c.systemd.services ? github-runner;
  }
  {
    name = "ssrjson-one";
    module = { lib, ... }: { services.antares-runners.instances.ssrjson.count = lib.mkForce 1; };
    check =
      c:
      c.systemd.services ? ssrjson-runner-1
      && !(c.systemd.services ? ssrjson-runner-2)
      && lib.hasInfix "/home/ssrjsonrunner/runner-1" c.systemd.services.ssrjson-runner-1.script;
  }
  {
    name = "nixdev-off";
    module = { lib, ... }: { services.antares-runners.instances.nixdev.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? ssrjsonnixdev)
      && !(c.systemd.services ? ssrjson-nixdev-runner)
      && !(c.systemd.timers ? restart-ssrjson-nixdev-runner)
      && c.systemd.services ? github-runner;
  }
  {
    name = "runner-collision";
    module = { lib, ... }: {
      services.antares-runners.instances.nixdev.user = lib.mkForce "actionrunner";
    };
    check = c: true;
    valid = false;
  }
  {
    name = "monitor-off";
    module = { lib, ... }: { services.telegram-output-monitor-bot.enable = lib.mkForce false; };
    check =
      c: !(c.systemd.services ? telegram-output-monitor-bot) && !(c.age.secrets ? monitorCfgAntaresRpi);
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
      && !(c.systemd.services ? xray-helper)
      && !(c.systemd.paths ? xray-helper)
      && !(c.systemd.generators ? antares-agent-mounts)
      && !(c.age.secrets ? antaresAgentEnv)
      && !(c.age.secrets ? agentRelayRabbitKey)
      && lib.all (r: !(lib.hasInfix "agent_work" r)) c.systemd.tmpfiles.rules
      && c.systemd.services ? xray;
  }
  {
    name = "napcat-dependency";
    module = { lib, ... }: { services.napcat.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? napcat)
      && !(c.systemd.services ? napcat)
      && !(c.systemd.services ? napcat-watchdog)
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
    name = "qq-off";
    module = { lib, ... }: { antares.qq.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? napcat)
      && !(c.systemd.services ? napcat)
      && !(c.systemd.services ? qq-napcat-relay)
      && !(c.systemd.services ? qq-codex-agent)
      && !(c.systemd.services ? qq-codex-auth)
      && !(c.systemd.services ? qq-codex-login)
      && !(c.system.activationScripts ? qqCodexRestart)
      && !(c.age.secrets ? qqRelayEnv)
      && !(c.age.secrets ? qqCodexGhToken)
      && !(c.age.secrets ? napcatEnv);
  }
  {
    name = "qq-codex-off";
    module = { lib, ... }: { antares.qq.codex.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? qq-codex-agent)
      && !(c.systemd.services ? qq-codex-auth)
      && !(c.systemd.services ? qq-codex-login)
      && !(c.age.secrets ? qqCodexGhToken)
      && c.age.secrets ? qqRelayEnv
      && c.systemd.services ? qq-napcat-relay;
  }
  {
    name = "xray-off";
    module = { lib, ... }: {
      antares.xray.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.systemd.services ? xray)
      && !(c.systemd.services ? xray-sub)
      && !(c.systemd.services ? xray-helper)
      && !(c.systemd.paths ? xray-helper)
      && !(c.users.groups ? xray)
      && !(c.age.secrets ? xraySubUrl)
      && !(c.environment.variables ? http_proxy)
      && !(c.systemd.services.antares-agent.environment ? http_proxy)
      && !(lib.elem "xray.service" c.systemd.services.antares-agent.after);
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { antares.xray.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
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
    module = { lib, ... }: {
      services.antares-runners.instances.nixdev.serviceName = lib.mkForce "restart-github-runner";
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
        xray.enable = lib.mkForce false;
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
