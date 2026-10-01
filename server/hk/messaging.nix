{ lib, ... }:
{
  options.antares.messaging.enable = lib.mkEnableOption "HK messaging stack";
}
