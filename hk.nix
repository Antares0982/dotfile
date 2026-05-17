import ./_make-device.nix {
  server = {
    hk = true;
  };
  #
  system = "x86_64-linux";
  withHm = true;
}
