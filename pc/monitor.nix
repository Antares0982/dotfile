{
  config,
  antares-monitor,
  ...
}:
{
  imports = [ antares-monitor.nixosModules.default ];

  services.telegram-output-monitor-bot = {
    enable = true;
    environmentFile = config.age.secrets.monitorCfgAntaresPc.path;
  };

  # The module runs the bot as an isolated DynamicUser; it has no proxy option,
  # so inject the local proxy the PC needs to reach Telegram via systemd env.
  systemd.services.telegram-output-monitor-bot.environment = {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
  };
}
