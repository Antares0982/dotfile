{ ... }:
{
  imports = [
    ../vps.nix
    ./disk-config.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.loader.efi.canTouchEfiVariables = false;
  users.users.antares.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3DEDDiBMHxE1V/aXD81+cBY8uRnoT6V8wrY1/DHFvj antares@sz"
  ];
}
