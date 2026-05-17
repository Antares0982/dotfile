{
  config,
  pkgs,
  kernelPatches,
  nix-rpi5,
  ...
}:
{
  boot.loader.raspberry-pi = {
    configurationLimit = 1;
    bootloader = "kernel";
  };

  hardware.raspberry-pi.config = {
    all = {
      base-dt-params = {
        pciex1 = {
          enable = true;
        };
        pciex1_gen = {
          enable = true;
          value = 3;
        };
      };
    };
  };
}
