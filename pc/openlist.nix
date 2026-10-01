{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.openlist.enable = lib.mkEnableOption "OpenList";

  config = lib.mkIf config.services.openlist.enable {
    systemd.services.openlist = {
      description = "OpenList";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        OPENLIST_ADDR = "127.0.0.1";
        OPENLIST_HTTP_PORT = "5244";
        OPENLIST_SITE_URL = "http://127.0.0.1:5244";
      };

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.openlist} server --data /var/lib/openlist --log-std";
        DynamicUser = true;
        StateDirectory = "openlist";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/openlist";
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
