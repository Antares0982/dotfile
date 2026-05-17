{
  config,
  lib,
  pkgs,
  ...
}:
let
  myqq = pkgs.qq.override {
    commandLineArgs = "--enable-wayland-ime";
  };
in
rec {
  environment.systemPackages = [ myqq ];
}
