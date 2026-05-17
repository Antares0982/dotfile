import ./_make-device.nix {
  pc = true;
  #
  system = "x86_64-linux";
  useProxy = true;
  withHm = true;
}
