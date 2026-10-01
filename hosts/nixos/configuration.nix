{ config, ... }: {
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
  services.antares-rpc-client.enable = true;
  antares.xray.enable = true;
  antares.proxy.enable = true;
  antares.autostart.enable = true;
  services.rabbitmq.enable = true;
  antares.desktop.enable = true;
  services.pipewire.enable = true;
  hardware.bluetooth.enable = true;
  i18n.inputMethod.enable = true;
}
