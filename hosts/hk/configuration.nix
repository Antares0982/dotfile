{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
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
  services.mysql.enable = true;
  services.mysqlBackup.enable = config.services.mysql.enable;
  imports = [
    ../../server
    ../../server/hk
  ];
  networking.hostName = "hk";
  networking.domain = "chr.fan";
  services.mysqlBackup = {
    calendar = "03:15:00";
    databases = [
      "site_metrics"
      "test"
      "wordpress"
      "wordpress-en"
      "wordpress_en"
    ];
    singleTransaction = true;
  };
  environment.etc."zsh/p10k.zsh".source = ../../resource/hk-p10k.zsh;
  _module.args = {
    myXray = inputs.myXray.packages.${system}.default;
    antares-rpc-client = inputs.antares-rpc-client.packages.${system}.default;
    visitor-badge = inputs.visitor-badge.packages.${system}.default;
    blog = inputs.blog;
  };
}
