{ config, pkgs, ... }:
{
  imports = [
    ./users
  ]
  ++ [
    ./acme.nix
    ./couchdb.nix
    ./mail.nix
    ./wordpress.nix
    ./visitorbadge.nix
  ];
}
