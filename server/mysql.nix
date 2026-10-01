{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.mysql.package = lib.mkIf config.services.mysql.enable pkgs.mariadb;
}
