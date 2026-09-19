{
  config,
  currentDevice,
  lib,
  pkgs,
  ...
}:
{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  services.mysqlBackup = lib.mkIf currentDevice.server.hk {
    enable = true;
    calendar = "03:15:00";
    databases = [
      "site_metrics"
      "test"
      "wordpress"
      "wordpress-en"
      "wordpress_en"
    ];
    singleTransaction = true;
  };
}
