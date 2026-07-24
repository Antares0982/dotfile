{
  config,
  antares-monitor,
  ...
}:
{
  imports = [ antares-monitor.nixosModules.default ];

  # HK has direct outbound access, so no proxy env is needed here.
  services.telegram-output-monitor-bot = {
    enable = true;
    environmentFile = config.age.secrets.monitorCfgAlice.path;
  };
}
