{ pkgs, myXray, ... }:
let
  xs = import ../../../common/xs.nix {
    inherit pkgs myXray;
  };
in
{
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
}
