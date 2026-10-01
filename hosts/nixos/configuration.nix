{ ... }: {
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy = "http://127.0.0.1:1081";
  services.antares-rpc-client.enable = true;
}
