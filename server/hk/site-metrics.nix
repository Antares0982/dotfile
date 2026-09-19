{
  config,
  pkgs,
  visitor-badge,
  ...
}:
let
  metricsDir = "/var/lib/site-metrics";
  metricsTool = pkgs.runCommand "site-metrics" { } ''
    mkdir -p $out/bin
    install -m755 ${./site-metrics.py} $out/bin/site-metrics
    sed -i "1s|.*|#!${pkgs.python3}/bin/python3|" $out/bin/site-metrics
  '';
  command = "${metricsTool}/bin/site-metrics";
  paths = [
    config.services.mysql.package
    visitor-badge
  ];
in
{
  users.users.site-metrics = {
    isSystemUser = true;
    group = "site-metrics";
    description = "Site metrics aggregator";
  };
  users.groups.site-metrics = { };

  services.mysql = {
    ensureDatabases = [ "site_metrics" ];
    ensureUsers = [
      {
        name = "site-metrics";
        ensurePermissions."site_metrics.*" = "SELECT, INSERT, UPDATE, DELETE";
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${metricsDir} 0755 site-metrics site-metrics -"
  ];

  systemd.services.site-metrics-init = {
    description = "Initialize site metrics";
    after = [ "mysql.service" ];
    requires = [ "mysql.service" ];
    before = [ "site-metrics.service" ];
    wantedBy = [ "multi-user.target" ];
    path = paths;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${command} init";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ metricsDir ];
    };
  };

  systemd.services.site-metrics = {
    description = "Aggregate nginx site metrics";
    after = [
      "mysql.service"
      "nginx.service"
      "site-metrics-init.service"
    ];
    requires = [
      "mysql.service"
      "site-metrics-init.service"
    ];
    path = paths;
    serviceConfig = {
      Type = "oneshot";
      User = "site-metrics";
      Group = "site-metrics";
      ExecStart = "${command} update";
      SupplementaryGroups = [ "nginx" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ReadOnlyPaths = [ "/var/log/nginx" ];
      ReadWritePaths = [ metricsDir ];
    };
  };

  systemd.timers.site-metrics = {
    description = "Periodically aggregate site metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
      Persistent = true;
    };
  };

}
