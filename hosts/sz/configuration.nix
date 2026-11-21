{ inputs, pkgs, ... }:
{
  antares.mihomo.publicInterface = "eth0";
  antares.proxy = {
    enable = true;
    insideGFW = true;
  };
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#ff8700";
  };
  imports = [
    ../../server
    ../../server/sz
    ../../modules/l4d2.nix
    ../../modules/l4d2-files.nix
  ];
  networking.hostName = "sz";
  antares.l4d2 = {
    enable = true;
    serverName = "Antares SZ L4D2";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHB94ncYnwgquf/Zqd92Bdnxvcibo042d0VbQvf9TSR4 antares@sz-l4d2"
    ];
    fileServer = {
      domain = "sz.chr.fan";
      enable = true;
    };
  };
  _module.args = {
    l4d2-addons = inputs.l4d2-plugins.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
  system.stateVersion = "26.11";
}
