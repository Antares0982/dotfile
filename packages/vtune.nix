{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeDesktopItem,
  alsa-lib,
  at-spi2-atk,
  cups,
  elfutils,
  expat,
  gdbm,
  gtk3,
  libdrm,
  libgbm,
  libuuid,
  libxcrypt-legacy,
  libxkbcommon,
  libxcomposite,
  libxdamage,
  libxext,
  libxrandr,
  ncurses5,
  nspr,
  nss,
  numactl,
  systemd,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "intel-oneapi-vtune";
  version = "2026.4.0";

  src = fetchurl {
    url = "https://apt.repos.intel.com/oneapi/pool/main/intel-oneapi-vtune-${finalAttrs.version}-20_amd64.deb";
    sha256 = "bf538c87b8ca9af1e56ba196a8e9b94141c16deaecf17c37be9c27feb845bb34";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    cups
    elfutils
    expat
    gdbm
    gtk3
    libdrm
    libgbm
    libuuid
    libxcrypt-legacy
    libxkbcommon
    libxcomposite
    libxdamage
    libxext
    libxrandr
    ncurses5
    nspr
    nss
    numactl
    systemd
    zlib
  ];

  runtimeDependencies = [ (lib.getLib systemd) ];
  autoPatchelfIgnoreMissingDeps = [
    "libffi.so.6"
    "libgdbm.so.4"
    "libsycl.so.9"
    "libopencl-clang.so.14"
    "liboutputgenerator.so"
  ];
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/opt" "$out/bin" "$out/share/icons/hicolor/128x128/apps"
    mv opt/intel/oneapi/vtune/* "$out/opt/vtune"
    ln -s "$out/opt/vtune/bin64/resources/app/icons/VTune.png" \
      "$out/share/icons/hicolor/128x128/apps/vtune.png"
    ln -s "${finalAttrs.desktopItem}/share/applications" "$out/share/applications"
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "$out/opt/vtune/bin64")
    for command in vtune vtune-gui vtune-server; do
      makeWrapper "$out/opt/vtune/bin64/$command" "$out/bin/$command" \
        "''${gappsWrapperArgs[@]}"
    done
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/vtune" --version
    "$out/bin/vtune-gui" --help > /dev/null
    test -f "$out/share/icons/hicolor/128x128/apps/vtune.png"
    runHook postInstallCheck
  '';

  desktopItem = makeDesktopItem {
    name = "vtune-gui";
    desktopName = "Intel VTune Profiler";
    exec = "vtune-gui %f";
    icon = "vtune";
    categories = [ "Development" ];
  };

  meta = {
    description = "Intel VTune Profiler";
    homepage = "https://www.intel.com/content/www/us/en/developer/tools/oneapi/vtune-profiler.html";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "vtune-gui";
  };
})
