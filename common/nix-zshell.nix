{ pkgs, ... }:
let
  nix-zshell = (import ../packages { inherit pkgs; }).nix-zshell;
in
{
  environment.systemPackages = [
    nix-zshell
  ];
}
