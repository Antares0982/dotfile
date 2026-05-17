{
  config,
  pkgs,
  rust-overlay,
  ...
}:
let
  rust-overlay-minimal = pkgs.rust-bin.stable.latest.minimal;
in
{
  nixpkgs.overlays = [
    rust-overlay
  ];
  environment.systemPackages = [
    (rust-overlay-minimal.override {
      extensions = [
        "rust-src"
        "rustfmt"
        "clippy"
      ];
      targets = [
        "aarch64-unknown-linux-gnu"
        "aarch64-linux-android"
        "x86_64-unknown-linux-musl"
        "aarch64-unknown-linux-musl"
      ];
    })
  ];
}
