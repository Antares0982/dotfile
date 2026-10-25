{
  config,
  lib,
  pkgs,
  ...
}:
let
  package = (import ../packages { inherit pkgs; }).gpu-unlock.override {
    inherit (config.boot) kernelPackages;
  };
in
{
  options.antares.gpuUnlock.enable = lib.mkEnableOption "the RTX 3090 tensor unlock at 0000:01:00.0";

  config = lib.mkIf config.antares.gpuUnlock.enable {
    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = "GPU unlock requires a systemd initrd.";
      }
    ];

    boot.kernelParams = [ "gpu_unlock.targets=0000:01:00.0" ];
    boot.extraModulePackages = [ package ];
    hardware.firmware = [ package.firmware ];
    boot.initrd.availableKernelModules = [ "gpu_unlock" ];
    boot.initrd.systemd.services.gpu-unlock = {
      description = "Unlock RTX 3090 tensor throughput";
      wantedBy = [ "sysinit.target" ];
      before = [
        "systemd-modules-load.service"
        "systemd-udev-trigger.service"
        "systemd-udevd.service"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        ${pkgs.kmod}/bin/modprobe gpu_unlock
      '';
    };
  };
}
