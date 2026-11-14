{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  find-nix-gc-roots = (import ../packages { inherit pkgs; }).find-nix-gc-roots;
in
{
  nixpkgs.config.allowUnfree = true;
  documentation.doc.enable = false;
  environment.systemPackages =
    with pkgs;
    [
      bat
      cachix
      delta
      fd
      file
      find-nix-gc-roots
      gh
      git
      gnupg
      jq
      kitty.terminfo
      nano
      neovim
      net-tools
      nixfmt
      p7zip
      python3
      ripgrep
      statix
      stylua
      tree
      tree-sitter
      uv
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ];
}
