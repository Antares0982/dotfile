{
  config,
  pkgs,
  lib,
  myXray,
  ...
}:
let
  userenvs = import ./_userenv.nix;
in
{
  systemd.user.services.xray = {
    Unit = {
      Description = "Xray for OpenAI";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = "${userenvs.home}/xray";
      ExecStart = "${myXray}/bin/xray -c config.json";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
