{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  python3,
  zstd,
  linuxPackages,
  kernelPackages ? linuxPackages,
}:
let
  src = fetchFromGitHub {
    owner = "JustAResearcher";
    repo = "gpu-unlock-ada";
    rev = "4e7fefcc4923f9e083d5324dc75a7d2f906af77f";
    hash = "sha256-pMyw74XF3F1DeDABpRzRJlALZZ1SD7YUbVFXUrMrM5Q=";
  };
  nvidiaSource = fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-610.43.03.tar.xz";
    hash = "sha256-fhGJI8eiPtw2EU1jJzpG4+BOmvmGlaQiA+esLf6fwdw=";
  };
  nvidiaUtils = fetchurl {
    url = "https://archive.cachyos.org/archive/cachyos-v3/nvidia-utils-610.43.03-1-x86_64_v3.pkg.tar.zst";
    hash = "sha256-4X58ku7/oXiw/h9A6xekcJX4/Dzkp3vxFc9b1aTfhuk=";
  };
  firmware = stdenv.mkDerivation {
    pname = "gpu-unlock-firmware";
    version = "610.43.03";
    inherit src;
    dontFixup = true;
    nativeBuildInputs = [
      python3
      zstd
    ];
    buildPhase = ''
      runHook preBuild
      mkdir inputs
      ln -s ${nvidiaSource} inputs/${nvidiaSource.name}
      ln -s ${nvidiaUtils} inputs/${nvidiaUtils.name}
      make firmware INPUTS="$PWD/inputs" ASSETS="$PWD/assets"
      runHook postBuild
    '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      make test-full ASSETS="$PWD/assets"
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      make install-firmware install-licenses ASSETS="$PWD/assets" DESTDIR="$out" \
        FWDIR=/lib/firmware/gpu-unlock/610.43.03 LICENSEDIR=/share/licenses
      runHook postInstall
    '';
    meta = {
      description = "Pinned firmware for the GPU tensor unlock";
      license = [
        lib.licenses.gpl2Only
        lib.licenses.unfreeRedistributableFirmware
      ];
      platforms = [ "x86_64-linux" ];
    };
  };
  inherit (kernelPackages) kernel kernelModuleMakeFlags;
in
kernelPackages.stdenv.mkDerivation {
  pname = "gpu-unlock";
  version = "1.1.1-4e7fefc";
  inherit src;
  sourceRoot = "${src.name}/kernel/gpu_unlock";
  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];
  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];
  enableParallelBuilding = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M="$PWD" INSTALL_MOD_PATH="$out" \
      ${lib.escapeShellArgs kernelModuleMakeFlags} modules_install
    runHook postInstall
  '';
  passthru = { inherit firmware; };
  meta = {
    description = "Pre-driver NVIDIA tensor throughput unlock";
    homepage = "https://github.com/JustAResearcher/gpu-unlock-ada";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
