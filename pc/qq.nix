{
  config,
  lib,
  pkgs,
  ...
}:
let
  myqq = pkgs.qq.override {
    # nixpkgs only passes --ozone-platform-hint=auto, which Electron re-resolves
    # at startup and can land on x11. An explicit --ozone-platform skips that
    # resolution entirely: Electron only consults the hint when --ozone-platform
    # is absent (shell/browser/electron_browser_main_parts_linux.cc).
    # ponytail: no X11 fallback left; drop this if the box ever runs an X session.
    commandLineArgs = "--ozone-platform=wayland --enable-wayland-ime";
  };
in
rec {
  environment.systemPackages = [ myqq ];
}
