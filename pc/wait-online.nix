{ lib, ... }:
{
  options.antares.waitOnline.enable = lib.mkEnableOption "user connectivity checks";
}
