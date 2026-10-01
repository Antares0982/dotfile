{ config, lib, ... }:
let
  cfg = config.antares.qq;
in
{
  options.antares.qq = {
    enable = lib.mkEnableOption "QQ stack";
    napcat.enable = lib.mkEnableOption "NapCat";
    relay.enable = lib.mkEnableOption "QQ relay";
    codex.enable = lib.mkEnableOption "QQ Codex";
  };
  config = {
    services.napcat.enable = cfg.enable && cfg.napcat.enable;
    services.qq-napcat-relay.enable = cfg.enable && cfg.relay.enable;
    services.qq-codex-agent.enable = cfg.enable && cfg.codex.enable;
  };
}
