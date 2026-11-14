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
  nvidiaInstaller = fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/610.43.03/NVIDIA-Linux-x86_64-610.43.03-no-compat32.run";
    hash = "sha256-4IRFHbcwpt8p09dPZVdJxNI248lF99lLUgXoQxj+L5A=";
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
    postPatch = ''
      substituteInPlace firmware/NOTICE.md \
        --replace-fail '610.43.03 package in `artifacts-610.43.03.json`.' \
          '610.43.03 official installer, with hashes from `artifacts-610.43.03.json`.' \
        --replace-fail "that package's complete" "the installer's complete" \
        --replace-fail '`usr/share/licenses/nvidia-utils/LICENSE`' '`LICENSE`'
    '';
    buildPhase = ''
      runHook preBuild
      sh ${nvidiaInstaller} --extract-only --target installer
      PYTHONPATH=firmware python3 - <<'PY'
      import json
      from pathlib import Path
      import generate_v67 as v67

      manifest = json.loads(v67.MANIFEST.read_text())
      assets = Path("assets")
      assets.mkdir()
      for name, data, expected in (
          ("gsp_ga10x.bin", Path("installer/firmware/gsp_ga10x.bin").read_bytes(), v67.GSP_SHA256),
          ("NVIDIA-LICENSE", Path("installer/LICENSE").read_bytes(),
           manifest["source_artifacts"][2]["notice"]["sha256"]),
          (manifest["generated_payload"]["filename"], v67.build_payload(), v67.PAYLOAD_SHA256),
          (v67.AD102_PAYLOAD_NAME, v67.build_ad102_payload(), v67.AD102_PAYLOAD_SHA256),
      ):
          if v67.sha256(data) != expected:
              raise ValueError(f"SHA-256 mismatch: {name}")
          (assets / name).write_bytes(data)
      PY
      mkdir assets.src
      tar -xf ${nvidiaSource} -C assets.src
      sourceDir="$PWD/assets.src/NVIDIA-kernel-module-source-610.43.03"
      python3 firmware/extract_boot_assets.py "$sourceDir" "$PWD/assets"
      python3 firmware/extract_boot_assets.py "$sourceDir" "$PWD/assets" --chip ad102
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
