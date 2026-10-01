{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  antares.xray.enable = true;
  antares.proxy.enable = true;
  environment.variables.NIX_DOT_FILES = "/Users/antares/Documents/Nix";
  antares.nixShell.enable = true;
  antares.systemCompiler.enable = true;
  imports = [ ../../mac ];
  _module.args = {
    myXray = inputs.myXray.packages.${system}.default;
  };
}
