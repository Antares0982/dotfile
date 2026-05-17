{
  config,
  pkgs,
  lib,
  antares-monitor,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
in
{
  systemd.user.services.monitor = {
    Unit = {
      Description = "${envs.usernameCap} Monitor Service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = "${antares-monitor}/bin/monitor.py";
      EnvironmentFile = "/run/agenix/monitorCfgAntaresPc";
      Environment = [
        "http_proxy=${envs.envs.http_proxy}"
        "https_proxy=${envs.envs.https_proxy}"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
