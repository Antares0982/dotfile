{ config, pkgs, ... }:
let
  nix-zshell = pkgs.callPackage ./../common/_nix-zshell.nix { };
in
{
  environment.variables = {
    NIX_DOT_FILES = "/Users/antares/Documents/Nix";
    NIX_BUILD_SHELL = "${nix-zshell}/bin/nix-zshell";
  };
}
