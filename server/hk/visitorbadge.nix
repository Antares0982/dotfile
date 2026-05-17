{
  config,
  lib,
  pkgs,
  visitor-badge,
  ...
}:
{
  systemd.services.visitorbadge = {
    description = "Visitor Badge Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      VISITOR_BADGE_COUNTERFILE = "/var/visitor/counterfile.txt";
      VISITOR_BADGE_HOST = "0.0.0.0";
    };
    serviceConfig = {
      User = "visitorbadge";
      ExecStart = "${visitor-badge}/bin/main.py";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
