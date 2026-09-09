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
    ./visitorbadge.nix
    ./matrix-appservice.nix
  ];
}
