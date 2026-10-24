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
  antares.starship = {
    enable = true;
    settings.palettes.host = {
      cwd_bg = "#ff5faf";
      cwd_fg = "#000000";
    };
  };
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
