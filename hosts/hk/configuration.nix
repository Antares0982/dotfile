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
    "couch.chr.fan" = { };
  };
  antares.blog.enable = true;
  antares.blog.metrics.enable = true;
  mailserver.enable = true;
  antares.alice.enable = true;
  antares.trilug.enable = true;
  services.telegram-bot-api.enable = true;
  antares.agentFiles.enable = true;
  antares.messaging.enable = true;
  services.rabbitmq.enable = true;
}
