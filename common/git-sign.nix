{ pkgs, ... }:
let
  git-ssh-sign = pkgs.callPackage ./_git-ssh-sign.nix { };
in
{
  environment.systemPackages = [
    git-ssh-sign
  ];
}
