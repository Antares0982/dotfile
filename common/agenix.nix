{
  config,
  pkgs,
  agenix,
  lib,
  currentDevice,
  ...
}:
let
  isPc = currentDevice.pc;
  isRpi = currentDevice.rpi;
  isHkServer = currentDevice.server.hk or false;
in
{
  environment.systemPackages = [ agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  age = {
    secrets = {
      password = {
        file = ../secrets/password.age;
      };
      serverPassword = {
        file = ../secrets/serverPassword.age;
      };
      superUserAuthorizedKey = {
        file = ../secrets/superUserAuthorizedKey.age;
      };
      gitAuthorizedKey = {
        file = ../secrets/gitAuthorizedKey.age;
      };
    }
    # ---- PC only ----
    // lib.optionalAttrs isPc {
      ghToken = {
        file = ../secrets/gh-token.age;
        owner = "antares";
        group = "users";
        mode = "400";
      };
      monitorCfgAntaresPc = {
        file = ../secrets/monitor-cfg-antares-pc.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
      rabbitClientCfgAntaresPc = {
        file = ../secrets/rabbit-client-cfg-antares-pc.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
      deepseekAPIKey = {
        file = ../secrets/deepseek-apikey.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
    }
    # ---- RPi only ----
    // lib.optionalAttrs isRpi {
      monitorCfgAntaresRpi = {
        file = ../secrets/monitor-cfg-antares-rpi.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
      rabbitClientCfgAntaresRpi = {
        file = ../secrets/rabbit-client-cfg-antares-rpi.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
      rabbitClientCfgActionrunner = {
        file = ../secrets/rabbit-client-cfg-actionrunner.age;
        owner = "actionrunner";
        group = "users";
        mode = "440";
      };
      hermesEnv = {
        file = ../secrets/hermes-env.age;
        owner = "hermes";
        group = "users";
        mode = "400";
      };
      # Stays root-owned. systemd reads EnvironmentFile= before dropping
      # privileges, so the agent uid never gets read access to the file.
      antaresAgentEnv = {
        file = ../secrets/antares-agent-env.age;
        mode = "400";
      };
      # The relay's broker credentials, owned by the relay's uid rather than
      # the agent's. F19: the sandbox blocks writes outside cwd but not reads,
      # so anything the agent uid can read, the model can read. Same
      # certificate the (now retired) hermes bridge used.
      agentRelayRabbitCa = {
        file = ../secrets/hermes-rabbit-ca.age;
        owner = "agent-relay";
        group = "users";
        mode = "400";
      };
      agentRelayRabbitCert = {
        file = ../secrets/hermes-rabbit-cert.age;
        owner = "agent-relay";
        group = "users";
        mode = "400";
      };
      agentRelayRabbitKey = {
        file = ../secrets/hermes-rabbit-key.age;
        owner = "agent-relay";
        group = "users";
        mode = "400";
      };
      hermesRabbitCa = {
        file = ../secrets/hermes-rabbit-ca.age;
        owner = "hermes";
        group = "users";
        mode = "400";
      };
      hermesRabbitCert = {
        file = ../secrets/hermes-rabbit-cert.age;
        owner = "hermes";
        group = "users";
        mode = "400";
      };
      hermesRabbitKey = {
        file = ../secrets/hermes-rabbit-key.age;
        owner = "hermes";
        group = "users";
        mode = "400";
      };
      napcatEnv = {
        file = ../secrets/napcat-env.age;
        owner = "napcat";
        group = "users";
        mode = "400";
      };
      qqRelayEnv = {
        file = ../secrets/qq-relay-env.age;
        owner = "napcat";
        group = "users";
        mode = "400";
      };
      # Host, port, vhost and credentials for the relay's broker connection --
      # the retired hermes bridge's values, reused wholesale. Its own file
      # rather than a second owner on hermes-env.age, which carries a good deal
      # more than these five lines.
      agentRelayEnv = {
        file = ../secrets/agent-relay-env.age;
        owner = "agent-relay";
        group = "users";
        mode = "400";
      };
      qqRelayRabbitCa = {
        file = ../secrets/hermes-rabbit-ca.age;
        owner = "napcat";
        group = "users";
        mode = "400";
      };
      qqRelayRabbitCert = {
        file = ../secrets/hermes-rabbit-cert.age;
        owner = "napcat";
        group = "users";
        mode = "400";
      };
      qqRelayRabbitKey = {
        file = ../secrets/hermes-rabbit-key.age;
        owner = "napcat";
        group = "users";
        mode = "400";
      };
      xraySubUrl = {
        file = ../secrets/xraysub.age;
        owner = "antares";
        group = "xray";
        mode = "440";
      };
      xrayTemplateJson = {
        file = ../secrets/xray-template-json.age;
        owner = "antares";
        group = "xray";
        mode = "440";
      };
    }
    # ---- HK server only ----
    // lib.optionalAttrs isHkServer {
      cloudflareEnv = {
        file = ../secrets/cloudflare-env.age;
        owner = "acme";
        group = "nginx";
      };
      monitorCfgAlice = {
        file = ../secrets/monitor-cfg-alice.age;
        owner = "alice";
        group = "users";
        mode = "440";
      };
      rabbitClientCfgAlice = {
        file = ../secrets/rabbit-client-cfg-alice.age;
        owner = "alice";
        group = "users";
        mode = "440";
      };
      rabbitClientCfgOpenai = {
        file = ../secrets/rabbit-client-cfg-openai.age;
        owner = "openai";
        group = "users";
        mode = "440";
      };
      mailPasswordAntares = {
        file = ../secrets/mail-password-antares.age;
      };
      mailPasswordAlyr = {
        file = ../secrets/mail-password-alyr.age;
      };
      couchdbAdminPassword = {
        file = ../secrets/couchdb-password.age;
        owner = "couchdb";
        group = "couchdb";
        mode = "400";
      };
      rabbitmqDefinitions = {
        file = ../secrets/rabbitmq-definitions.age;
        owner = "rabbitmq";
        group = "rabbitmq";
        mode = "400";
      };
      pwaEnv = {
        file = ../secrets/pwa-env.age;
        owner = "pwa";
        group = "users";
        mode = "400";
      };
    };
    identityPaths = [ "/etc/ssh/agenix" ];
  };
}
