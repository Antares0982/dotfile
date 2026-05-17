{
  config,
  pkgs,
  lib,
  antares-monitor,
  ...
}:
let
  shellenv = import ../common/shellEnv.nix;
in
{
  systemd.services.monitor = {
    description = "Antares Monitor Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      export PATH=$PATH:${shellenv.sysBin}
      ${antares-monitor}/bin/monitor.py
    '';
    environment = {
      http_proxy = "http://127.0.0.1:1081";
      https_proxy = "http://127.0.0.1:1081";
    };
    serviceConfig = {
      EnvironmentFile = config.age.secrets.monitorCfgAntaresRpi.path;
      User = "antares";
    };
  };
}
