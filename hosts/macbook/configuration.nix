{
  antares.proxy = {
    enable = true;
    insideGFW = true;
    lan = true;
  };
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#ff5faf";
  };
  antares.mihomo.dashboardOrigins = [ "http://192.168.0.5:17900" ];
  environment.variables.NIX_DOT_FILES = "/Users/antares/Documents/Nix";
  antares.nixShell.enable = true;
  antares.systemCompiler.enable = true;
  imports = [ ../../mac ];
}
