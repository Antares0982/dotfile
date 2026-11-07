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
    settings.palettes.host.color_os = "#ff5faf";
  };
  antares.xray.enable = false;
  antares.mihomo = {
    enable = true;
    singapore = true;
    dashboardLan = true;
    dashboardOrigins = [ "http://192.168.0.5:17900" ];
  };
  antares.proxy.enable = true;
  antares.proxy.socksUrl = "socks5h://127.0.0.1:1081";
  environment.variables.NIX_DOT_FILES = "/Users/antares/Documents/Nix";
  antares.nixShell.enable = true;
  antares.systemCompiler.enable = true;
  imports = [ ../../mac ];
  _module.args = {
    myXray = inputs.myXray.packages.${system}.default;
  };
}
