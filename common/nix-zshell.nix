{ pkgs, ... }:
let
  nix-zshell = pkgs.callPackage ../packages/nix-zshell.nix { };
in
{
  environment.systemPackages = [
    nix-zshell
  ];
}
