{ config, pkgs, ... }:
{
  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
      timeout = 10;
    };
    blacklistedKernelModules = [ "nouveau" ];
    initrd.kernelModules = [ ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_zen);
    # kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [
      "kvm-intel"
      "nvidia_drm"
    ];
    extraModulePackages = [
    ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    extraModprobeConfig = ''
      options hid_apple fnmode=2
    '';
  };
}
