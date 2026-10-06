import ./_make-device.nix {
  server.sz = true;
  system = "x86_64-linux";
  useProxy = true;
}
