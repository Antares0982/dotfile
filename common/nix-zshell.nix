{ pkgs, ... }:
let
  nix-zshell = pkgs.callPackage ./_nix-zshell.nix { };
in
{
  environment.systemPackages = [
    nix-zshell
  ];
}
