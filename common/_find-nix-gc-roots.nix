{
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "_find-nix-gc-roots";
  name = "_find-nix-gc-roots";

  src = ./find-nix-gc-roots-script;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/fnr
    chmod +x $out/bin/fnr
  '';
}
