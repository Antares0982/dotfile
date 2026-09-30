{ pkgs, ... }:
let
  git-ssh-sign = pkgs.callPackage ../packages/git-ssh-sign.nix { };
in
{
  environment.systemPackages = [
    git-ssh-sign
  ];
}
