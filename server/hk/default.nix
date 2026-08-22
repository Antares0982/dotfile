{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./blog.nix
    ./monitor.nix
    ./hermes-pwa.nix
    ./mail.nix
    ./wordpress.nix
    ./visitorbadge.nix
    ./matrix-appservice.nix
  ];
}
