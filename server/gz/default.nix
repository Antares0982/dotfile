{ ... }:
{
  imports = [
    ../vps.nix
    ./disk-config.nix
  ];
  users.users.antares.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS4Ty97Xiann8mMJHDjv5HqCzdideBuPq28PeVSHvZH antares@gz"
  ];
}
