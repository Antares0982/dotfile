{ inputs, pkgs, ... }:
{
  antares.proxy = {
    enable = true;
  };
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#ff8700";
  };
  imports = [
    ../../server
    ../../server/gz
    ../../modules/l4d2.nix
    ../../modules/l4d2-files.nix
  ];
  networking.hostName = "gz";
  antares = {
    l4d2 = {
      enable = true;
      fileServer.enable = true;
    };
  };
  _module.args = {
    l4d2-addons = inputs.l4d2-plugins.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
  system.stateVersion = "26.11";
}
