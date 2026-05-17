{
  pkgs,
  zsh,
  bashInteractive,
  replaceVars,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "nix-zshell";
  name = "nix-zshell";
  script = replaceVars ./nix-zshell-wrapper {
    inherit zsh bashInteractive;
  };

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    cp $script $out/bin/nix-zshell
    chmod +x $out/bin/nix-zshell
  '';
}
