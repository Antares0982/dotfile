{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.ydotool.enable {
    environment.systemPackages = [ pkgs.ydotool ];
    users.users.antares.extraGroups = [ "ydotool" ];
  };
}
