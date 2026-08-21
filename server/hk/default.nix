{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./blog.nix
    ./couchdb.nix
    ./monitor.nix
    ./hermes-pwa.nix
    ./mail.nix
    ./wordpress.nix
    ./visitorbadge.nix
    ./matrix-appservice.nix
  ];
}
