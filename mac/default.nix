{
  config,
  pkgs,
  lib,
  self,
  currentDevice,
  ...
}:
{
  imports = [
    ./env.nix
    ./packages.nix
    ./proxy.nix
    ./stdenv.nix
    ./xray.nix
  ]
  ++ [
    ../common/nix.nix
    ../common/packages.nix
  ];

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  nixpkgs.config.allowUnfree = true;
}
