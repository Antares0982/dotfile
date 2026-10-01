{
  config,
  lib,
  antares-monitor,
  ...
}:
{
  imports = [ antares-monitor.nixosModules.default ];
  options.antares.monitor.proxy = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
  };
  config = lib.mkIf config.services.telegram-output-monitor-bot.enable {
    systemd.services.telegram-output-monitor-bot.environment =
      lib.optionalAttrs (config.antares.monitor.proxy != null)
        {
          http_proxy = config.antares.monitor.proxy;
          https_proxy = config.antares.monitor.proxy;
        };
  };
}
