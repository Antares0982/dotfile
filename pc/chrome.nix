{
  config,
  pkgs,
  # pkgs-for-chrome,
  ...
}:
let
  # specified_version = "124.0.6367.118";
  # specified_version = "124.0.6367.91";
  # specified_version = "122.0.6261.57";
  # specified_version ="129.0.6668.100";
  specified_version = "135.0.7049.84";

  # google-chrome =
  #   (pkgs-for-chrome.google-chrome.override {
  #     # https://bbs.archlinux.org/viewtopic.php?id=291229&p=2
  #     # https://peter.sh/experiments/chromium-command-line-switches
  #     #  --use-angle=swiftshader
  #     commandLineArgs = "--enable-wayland-ime";
  #   }).overrideAttrs
  #     (oldAttrs: rec {
  #       version = specified_version;
  #       src = pkgs.fetchurl {
  #         url = "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${specified_version}-1_amd64.deb";
  #         # hash = "sha256-H3bv6WiVBl4j38ROZ80+SD9UO9ok+xxcKFxDd9yjWNY=";  # for 124.0.6367.118
  #         # hash = "sha256-Q3AUKzUsRzW00+WLhuri86QzBGk/rlq5Hk+NdoRbbM4="; # for 122.0.6261.57
  #         # hash = "sha256-5NITOnDEVd5PeyWT9rPVgFv5W5bP2h+bLM30hjmpgzs="; # for 129.0.6668.100
  #         hash = "sha256-ZygM2YuML23KPJQ8Kl5f2YqI+0vbXnC3fYk8l8R/nXk="; # for 135.0.7049.84
  #       };
  #       # LD_PRELOAD = "${pkgs.vulkan-loader}/lib/libvulkan.so.1";
  #     });
in
rec {
  environment.systemPackages = [
    pkgs.google-chrome
  ];
}
