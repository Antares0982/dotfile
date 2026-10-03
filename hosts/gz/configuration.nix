{ inputs, pkgs, ... }:
{
  imports = [
    ../../server
    ../../server/gz
  ];
  networking.hostName = "gz";
  services.xray.enable = true;
  antares.proxy = {
    enable = true;
    socksUrl = "socks5h://127.0.0.1:1080";
  };
  _module.args = {
    myXray = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.default;
    xray-sub = inputs.myXray.packages.${pkgs.stdenv.hostPlatform.system}.xray_sub;
  };
  environment.etc."zsh/p10k.zsh".source = ../../resource/hk-p10k.zsh;
  system.stateVersion = "26.11";
}
