{
  config,
  pkgs,
  lib,
  myXray,
  ...
}:
let
  xs = pkgs.writeShellApplication {
    name = "xs";
    runtimeInputs = [
      myXray
      pkgs.jq
      pkgs.curl
      pkgs.systemd
    ];
    text = builtins.readFile ../../../resource/xs.sh;
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
