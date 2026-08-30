{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./blog.nix
    ./monitor.nix
    ./mail.nix
    ./wordpress.nix
    ./visitorbadge.nix
    ./matrix-appservice.nix
  ];
}
