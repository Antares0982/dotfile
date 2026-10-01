{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.hardware.bluetooth.enable) {

    hardware.bluetooth = {
      powerOnBoot = true;
    };

  };
}
