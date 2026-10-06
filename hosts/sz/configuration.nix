{ inputs, pkgs, ... }:
{
  imports = [
    ../../server
    ../../server/sz
    ../../modules/l4d2.nix
    ../../modules/l4d2-files.nix
  ];
  networking.hostName = "sz";
  antares.l4d2.enable = true;
  antares.l4d2.serverName = "Antares SZ L4D2";
  antares.l4d2.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHB94ncYnwgquf/Zqd92Bdnxvcibo042d0VbQvf9TSR4 antares@sz-l4d2"
  ];
  antares.l4d2.fileServer.domain = "sz.chr.fan";
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
