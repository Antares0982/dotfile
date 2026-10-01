{ lib, config, ... }:
let
  asPort = 29328;
in
{
  options.antares.trilug.enable = lib.mkEnableOption "Tri-LUG bridge and reverse proxy";
  config = lib.mkIf (config.antares.messaging.enable && config.antares.trilug.enable) {
    assertions = [ { assertion = config.services.nginx.enable; message = "Tri-LUG requires services.nginx.enable."; } ];

  services.nginx.virtualHosts."tri-lug.chr.fan" = {
    enableACME = true;
    acmeRoot = null;
    forceSSL = true;

    extraConfig = ''
      client_max_body_size 50m;
    '';

    locations."/".extraConfig = ''
      proxy_pass http://127.0.0.1:${toString asPort};
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    '';
  };

  };
}
