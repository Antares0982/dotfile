{
  lib,
  config,
  pkgs,
  rust-overlay,
  ...
}:
let
  rust-overlay-minimal = pkgs.rust-bin.stable.latest.minimal;
in
{
  options.antares.rust.enable = lib.mkEnableOption "Rust development toolchain";
  config = lib.mkIf (config.antares.rust.enable) {

    nixpkgs.overlays = [
      rust-overlay
    ];
    environment.systemPackages = [
      (rust-overlay-minimal.override {
        extensions = [
          "clippy"
          "rust-analyzer"
          "rust-src"
          "rustfmt"
        ];
        targets = [
          "aarch64-unknown-linux-gnu"
          "aarch64-linux-android"
          "x86_64-unknown-linux-musl"
          "aarch64-unknown-linux-musl"
        ];
      })
    ];

  };
}
