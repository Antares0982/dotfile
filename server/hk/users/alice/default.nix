{
  config,
  pkgs,
  ...
}:
{
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  imports = [
    ./alice.nix
    ./luggpt.nix
    ./monitor.nix
  ]
  ++ [
    (import ../multiuser-rpc-client.nix {
      userenvs = import ./_userenv.nix;
    })
  ];
}
