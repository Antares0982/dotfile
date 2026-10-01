{
  pkgs,
  myXray ? null,
}:
{
  nix-zshell = pkgs.callPackage ./nix-zshell.nix { };
  git-ssh-sign = pkgs.callPackage ./git-ssh-sign.nix { };
  find-nix-gc-roots = pkgs.callPackage ./find-nix-gc-roots.nix { };
  blender-mcp = pkgs.callPackage ./blender-mcp.nix { };
  vtune = pkgs.callPackage ./vtune.nix { };
  xs = pkgs.callPackage ./xs.nix { inherit myXray; };
}
