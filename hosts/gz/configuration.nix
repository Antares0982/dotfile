{ inputs, pkgs, ... }:
{
  antares.starship = {
    enable = true;
    settings.palettes.host = {
      cwd_bg = "#ff8700";
      cwd_fg = "#000000";
    };
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
    proxy = {
      enable = true;
      socksUrl = "socks5h://127.0.0.1:1080";
    };
  };
  services.xray.enable = true;
  _module.args = {
    l4d2-addons = inputs.l4d2-plugins.packages.${pkgs.stdenv.hostPlatform.system}.default;
    myXray = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.default;
    xray-sub = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.xray_sub;
  };
  system.stateVersion = "26.11";
}
