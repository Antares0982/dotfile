import ./_make-device.nix {
  rpi = true;
  #
  system = "aarch64-linux";
  useProxy = true;
}
