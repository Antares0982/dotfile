{
  config,
  pkgs,
  lib,
  ...
}:
{
  nix = {
    settings = {
      substituters = [
        "https://nixos-raspberrypi.cachix.org"
        "https://hermes-agent.cachix.org"
      ];
      trusted-public-keys = [
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
      ];
    };
  };
}
