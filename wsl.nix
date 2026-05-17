import ./_make-device.nix {
  wsl = true;
  #
  system = "x86_64-linux";
  useProxy = true;
}
