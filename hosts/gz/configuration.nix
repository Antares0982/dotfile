{ inputs, pkgs, ... }:
{
  imports = [
    ../../server
    ../../server/gz
    ../../modules/l4d2.nix
    ../../modules/l4d2-files.nix
  ];
  networking.hostName = "gz";
  antares.l4d2.enable = true;
  antares.l4d2.fileServer.enable = true;
  services.xray.enable = true;
  antares.proxy = {
    enable = true;
    socksUrl = "socks5h://127.0.0.1:1080";
  };
  _module.args = {
    l4d2-addons = inputs.l4d2-plugins.packages.${pkgs.stdenv.hostPlatform.system}.default;
    myXray = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.default;
    xray-sub = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.xray_sub;
  };
  environment.etc."zsh/p10k.zsh".source = ../../resource/hk-p10k.zsh;
  system.stateVersion = "26.11";
}
