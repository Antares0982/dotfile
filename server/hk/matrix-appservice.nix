{ config, ... }:
let
  # mautrix-python appservice listener (appservice.port).
  # Must match the bridge config and the registration file's `url:`.
  asPort = 29328;
in
{
  # Reverse proxy tri-lug.chr.fan (443) to the local Matrix appservice
  # listener so li7g.com's Synapse can POST HS->AS transactions.
  # TLS cert is issued via DNS-01 (cloudflare); see ./acme.nix and
  # ../_domains.nix where tri-lug.chr.fan is registered.
  services.nginx.virtualHosts."tri-lug.chr.fan" = {
    enableACME = true;
    forceSSL = true;

    extraConfig = ''
      # appservice transaction bodies can be large
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
}
