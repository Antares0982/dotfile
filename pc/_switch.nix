{
  pkgs,
  python3,
  stdenvNoCC,
  fetchFromGitHub,
  pkg-config,
  ...
}:
let
  pyenv = python3.withPackages (
    pypkgs: with pypkgs; [
      (buildPythonPackage rec {
        pname = "pydotool";
        version = "v1.1.1";
        pyproject = true;
        src = fetchFromGitHub {
          owner = "Antares0982";
          repo = "pydotool";
          rev = version;
          sha256 = "sha256-hhfrnAOpTH0C6tKUvYJD8gLFuml3p9rjwsxMHmIw1p8=";
        };
        nativeBuildInputs = [
          setuptools
          cmake
          pkg-config
        ];
        preBuild = ''
          cd ..
        '';
      })
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "_switch";
  name = "_switch";
  src = builtins.path {
    path = ./_switch_dir;
    name = "antares-switch-src";
  };

  installPhase = ''
    mkdir -p $out/bin
    mkdir $out/lib
    cp $src/_switch.py $out/bin/_switch
    cp $src/_switch.sh $out/lib/_switch.sh
    chmod +x $out/bin/_switch
    substituteInPlace $out/bin/_switch \
      --replace-fail "@python@" "${pyenv}/bin/python3" \
      --replace-fail "@_switch_sh@" "$out/lib/_switch.sh"
  '';
}
