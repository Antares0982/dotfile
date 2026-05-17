{
  config,
  pkgs,
  lib,
  myXray,
  ...
}:
{
  systemd.services."xray" = {
    script = ''
      exec ${myXray}/bin/xray -c /var/lib/xray/config.json
    '';
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      User = "antares";
    };
  };
}
