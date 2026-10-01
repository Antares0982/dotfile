{
  config,
  currentDevice,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.services.mysql.enable) {

  services.mysql = {
    package = pkgs.mariadb;
  };

  services.mysqlBackup = lib.mkIf currentDevice.server.hk {
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

  };
}
