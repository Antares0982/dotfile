{ pkgs, ... }:
let
  git-ssh-sign = (import ../packages { inherit pkgs; }).git-ssh-sign;
in
{
  environment.systemPackages = [
    git-ssh-sign
  ];
}
