{
  config,
  lib,
  pkgs,
  currentDevice,
  ...
}:
let
  shouldBuildPc = currentDevice.pc;
  shouldBuildServer = lib.lists.any (x: x) (lib.attrsets.attrValues currentDevice.server);
  shouldBuildRpi = currentDevice.rpi;
  shouldBuildWSL = currentDevice.wsl;
in
{
  imports = [
    ./common/cachix.nix
  ]
  ++ lib.optionals shouldBuildPc [
    ./pc
  ]
  ++ lib.optionals shouldBuildServer [
    ./server
  ]
  ++ lib.optionals shouldBuildRpi [
    ./rpi
  ]
  ++ lib.optionals shouldBuildWSL [
    ./wsl
  ];
}
