{ lib, config, pkgs, myXray, osConfig, ... }:
let
  xs = (import ../../../packages { inherit pkgs myXray; }).xs;
in
{
  config = lib.mkIf (osConfig.antares.xray.enable) {

  home.packages = [
    myXray
    xs
  ];

  systemd.user.services.xray = {
    Unit = {
      Description = "xray User Service";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${myXray}/bin/xray -c %h/.config/xray/config.json";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  };
}
