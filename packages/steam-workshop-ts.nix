{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "steam-workshop-ts";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "K4ryuu";
    repo = "steam-workshop-ts";
    rev = "6d370b61c0cf39af595776c301bed8ef7786f307";
    hash = "sha256-No4KPggXsuo2z3M3eocUZwOmsP5iGG8f2opqUuTvgwU=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    bun build src/cli.ts --target=bun --outfile=dist/cli.js
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 dist/cli.js "$out/lib/steam-workshop-ts/cli.js"
    install -Dm644 LICENSE "$out/share/licenses/steam-workshop-ts/LICENSE"
    makeWrapper ${lib.getExe bun} "$out/bin/steam-workshop-ts" \
      --add-flags "$out/lib/steam-workshop-ts/cli.js"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/steam-workshop-ts" --help
    "$out/bin/steam-workshop-ts" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Search and download Steam Workshop items from the command line";
    homepage = "https://github.com/K4ryuu/steam-workshop-ts";
    license = lib.licenses.mit;
    mainProgram = "steam-workshop-ts";
    inherit (bun.meta) platforms;
  };
}
