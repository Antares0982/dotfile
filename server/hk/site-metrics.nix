{ lib,
  config,
  pkgs,
  visitor-badge,
  ...
}:
let
  metricsDir = "/var/lib/site-metrics";
  viewsLog = "/var/log/nginx/blog-views.log";
  badgeLog = "/var/log/nginx/visitor-badge.log";
  badgeFallback = pkgs.writeText "visitor-badge-unavailable.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="164" height="20" role="img" aria-label="visitors: unavailable"><title>visitors: unavailable</title><linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="r"><rect width="164" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#r)"><rect width="57" height="20" fill="#595959"/><rect x="57" width="107" height="20" fill="#1283c3"/><rect width="164" height="20" fill="url(#s)"/></g><g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11"><text x="28.5" y="15" fill="#010101" fill-opacity=".3">visitors</text><text x="28.5" y="14">visitors</text><text x="109.5" y="15" fill="#010101" fill-opacity=".3">unavailable</text><text x="109.5" y="14">unavailable</text></g></svg>
  '';
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
  options.antares.blog.metrics.enable = lib.mkEnableOption "blog statistics";
  config = lib.mkIf (config.antares.blog.enable && config.antares.blog.metrics.enable) {
    assertions = [ { assertion = config.services.mysql.enable; message = "Blog metrics require services.mysql.enable."; } ];

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


  services.nginx.commonHttpConfig = ''
    log_format siteviews escape=none
      '$time_iso8601	$remote_addr	$status	$request_uri	$http_user_agent';
  '';
  services.nginx.virtualHosts."chr.fan" = {
    extraConfig = ''
      access_log ${viewsLog} siteviews;
    '';
    locations = {
      "= /api/views.json" = {
        alias = "${metricsDir}/views.json";
        extraConfig = ''
          types { }
          default_type application/json;
          add_header Cache-Control "public, max-age=300";
          error_page 404 = @noviews;
        '';
      };
      "@noviews".extraConfig = ''
        default_type application/json;
        return 200 '{}';
      '';
      "= /api/visitor-badge.svg" = {
        alias = "${metricsDir}/visitor-badge.svg";
        extraConfig = ''
          access_log ${badgeLog} siteviews;
          types { }
          default_type image/svg+xml;
          add_header Cache-Control "no-cache, max-age=0, no-store, s-maxage=0, proxy-revalidate";
          expires -1;
          error_page 404 =200 /api/visitor-badge-unavailable.svg;
        '';
      };
      "= /api/visitor-badge-unavailable.svg" = {
        alias = badgeFallback;
        extraConfig = ''
          internal;
          access_log off;
          types { }
          default_type image/svg+xml;
        '';
      };
    };
  };
  };
}
