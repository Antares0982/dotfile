{
  pkgs,
  rustPlatform,
  lib,
  ...
}:
let
  _src = "${../src/git_credential_refresher}";
in
rustPlatform.buildRustPackage rec {
  pname = "git_credential_refresher";
  version = "0.1.0";
  src = _src;
  cargoHash = "sha256-sYdO3OCbgQv0kvEqTe+Ut+EbDjsxrSW7YBfcFEXlkwQ=";
}
