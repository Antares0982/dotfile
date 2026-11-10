{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.services.simple-moderation;
in
{
  imports = [ inputs.simple-moderation.nixosModules.default ];
  config = lib.mkMerge [
    { services.simple-moderation.enable = lib.mkDefault config.services.qq-codex-agent.enable; }
    (lib.mkIf cfg.enable {
      services.simple-moderation = {
        host = "127.0.0.1";
        port = 18765;
        apiKeyFile = config.age.secrets.simpleModerationKey.path;
      };
      age.secrets.simpleModerationKey = {
        file = ../secrets/simple-moderation-key.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      systemd.services.simple-moderation.restartTriggers = [
        config.age.secrets.simpleModerationKey.file
      ];
    })
  ];
}
