# Reproducible base mods for the L4D2 dedicated server.
# Produces a store tree with an `addons/` (+ `cfg/`) layout that is copied into
# the game directory at service start. Forum-distributed plugins (Left4DHooks,
# 8-survivor plugin) are NOT managed here; drop them into the persistent
# addons/sourcemod/{extensions,plugins} directory by hand (see default.nix).
{ pkgs }:
let
  # MetaMod:Source 1.11 stable (Linux)
  metamod = pkgs.fetchurl {
    url = "https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1156-linux.tar.gz";
    sha256 = "0nfqraavz90pypp0ii0mn4dycaj6rh9v55rbpbp8sib6bgby7ga8";
  };
  # SourceMod 1.11 stable (Linux)
  sourcemod = pkgs.fetchurl {
    url = "https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6970-linux.tar.gz";
    sha256 = "19r9gk56mb1nhwpw2bl8qqdznqc2cd2sc89fmj1jn6d7i87cvsvm";
  };
  # l4dtoolz 2.2.0 (accelerator74) - MetaMod plugin that unlocks sv_maxplayers.
  l4dtoolz = pkgs.fetchurl {
    url = "https://github.com/accelerator74/l4dtoolz/releases/download/2.2.0/l4dtoolz-l4d2-linux-ef2a8df.tar.gz";
    sha256 = "0zxrar91babhc1h5lvbkwaf7hg5n9x3cmv0h6c013kp6jsi3pw49";
  };
in
pkgs.runCommand "l4d2-managed-mods" { } ''
  mkdir -p $out
  tar -C $out -xzf ${metamod}
  tar -C $out -xzf ${sourcemod}
  tar -C $out -xzf ${l4dtoolz}
''
