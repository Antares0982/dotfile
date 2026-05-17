{
  config,
  pkgs,
  antares-rpc-client,
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
    ./openai.nix
    ./openaiXray.nix
  ]
  ++ [
    (import ../multiuser-rpc-client.nix {
      userenvs = import ./_userenv.nix;
    })
  ];
}
