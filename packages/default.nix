{ pkgs }:
{
  plangothic = pkgs.callPackage ./plangothic.nix { };
  nix-zshell = pkgs.callPackage ./nix-zshell.nix { };
  git-ssh-sign = pkgs.callPackage ./git-ssh-sign.nix { };
  gpu-unlock = pkgs.callPackage ./gpu-unlock.nix { };
  find-nix-gc-roots = pkgs.callPackage ./find-nix-gc-roots.nix { };
  blender-mcp = pkgs.callPackage ./blender-mcp.nix { };
  steam-workshop-ts = pkgs.callPackage ./steam-workshop-ts.nix { };
  vtune = pkgs.callPackage ./vtune.nix { };
  mihomo-tools = pkgs.callPackage ./mihomo-tools.nix { };
}
