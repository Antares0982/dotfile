import ./_make-device.nix {
  server.gz = true;
  system = "x86_64-linux";
  useProxy = true;
}
