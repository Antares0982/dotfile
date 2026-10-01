{ config, lib, ... }:
{
  options.antares.alice.enable = lib.mkEnableOption "Alice bot";
  config = lib.mkIf config.antares.alice.enable {
    age.secrets.aliceTelegramWebhookSecret = {
      file = ../../secrets/alice-telegram-webhook-secret.age;
      owner = "alice";
      group = "users";
      mode = "400";
    };
  };
}
