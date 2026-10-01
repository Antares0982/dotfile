{ lib }: [
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
]
