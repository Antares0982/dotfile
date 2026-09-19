{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./blog.nix
    ./site-metrics.nix
    ./monitor.nix
    ./mail.nix
    ./matrix-appservice.nix
  ];
}
