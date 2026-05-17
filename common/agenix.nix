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
    };
    identityPaths = [ "/home/antares/.ssh/agenix" ];
  };
}
