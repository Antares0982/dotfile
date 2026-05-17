{
  config,
  pkgs,
  lib,
  myXray,
  ...
}:
{
  home.packages = [
    myXray
  ];

  systemd.user.services.xray = {
    Unit = {
      Description = "xray User Service";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${myXray}/bin/xray -c %h/.config/xray/config.json";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
