{ config, pkgs, ... }:
{
  systemd.services.telegram-bot-api = {
    description = "Telegram Bot API";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      User = "alice";
      Group = "users";
      StateDirectory = "telegram-bot-api";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/telegram-bot-api";
      EnvironmentFile = config.age.secrets.telegramBotApiEnv.path;
      ExecStart = "${pkgs.telegram-bot-api}/bin/telegram-bot-api --local --http-ip-address=127.0.0.1 --http-port=60081 --dir=/var/lib/telegram-bot-api";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
  };
}
