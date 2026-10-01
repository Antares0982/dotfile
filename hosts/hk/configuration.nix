{ ... }: {
  services.telegram-output-monitor-bot.enable = true;
  services.antares-rpc-client.enable = true;
  services.xray.enable = true;
  services.nginx.enable = true;
  antares.acme.enable = true;
  networking.firewall.allowedUDPPorts = [
    53
    80
    443
  ];
  security.acme.certs = {
    "mail.alyr.dev" = { };
    "couch.chr.fan" = { };
  };
}
