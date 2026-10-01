{ ... }: {
  antares.xray.enable = true;
  antares.proxy.enable = true;
  environment.variables.NIX_DOT_FILES = "/Users/antares/Documents/Nix";
  antares.nixShell.enable = true;
  antares.systemCompiler.enable = true;
}
