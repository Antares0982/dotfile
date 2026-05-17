{
  config,
  lib,
  pkgs,
  ...
}:
rec {
  environment.systemPackages = [
    (pkgs.haruna.overrideAttrs {
      postFixup = ''
        wrapProgram $out/bin/haruna \
          --set LD_PRELOAD "${pkgs.vulkan-loader}/lib/libvulkan.so"
      '';
    })
  ];
}
