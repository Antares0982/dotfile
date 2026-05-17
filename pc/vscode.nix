{
  config,
  pkgs,
  lib,
  ...
}:
let
  vscode = pkgs.vscode.override (previous: {
    commandLineArgs = "--enable-wayland-ime=";
  });
in
rec {
  environment.systemPackages = [ vscode.fhs ];
}
