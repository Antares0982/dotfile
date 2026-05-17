{
  config,
  pkgs,
  lib,
  currentDevice,
  ...
}:
{
  nix.settings.extra-platforms = lib.unique ([ "i686-linux" ] ++ config.boot.binfmt.emulatedSystems);
}
