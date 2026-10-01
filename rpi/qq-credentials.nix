{ config, lib, ... }:
{
  config =
    lib.mkIf (config.services.qq-napcat-relay.enable || config.services.qq-codex-agent.enable)
      {
        age.secrets.qqRelayEnv = {
          file = ../secrets/qq-relay-env.age;
          owner = "napcat";
          group = "users";
          mode = "400";
        };
      };
}
