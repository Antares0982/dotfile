{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./couchdb.nix
    ./hermes-pwa.nix
    ./mail.nix
    ./wordpress.nix
    ./visitorbadge.nix
  ];
}
