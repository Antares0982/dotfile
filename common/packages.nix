{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  renewal = inputs.renewal.packages.${pkgs.stdenv.hostPlatform.system}.default;
  find-nix-gc-roots = (import ../packages { inherit pkgs; }).find-nix-gc-roots;
in
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    cachix
    delta
    eza
    fd
    find-nix-gc-roots
    gcc
    gdb
    gh
    git
    gnumake
    gnupg
    jq
    kitty.terminfo
    nano
    net-tools
    nixfmt
    nix-prefetch-scripts
    oh-my-zsh
    renewal
    ripgrep
    statix
    tree
    tree-sitter
    uv
    zsh
    zsh-powerlevel10k
  ];
}
