{ config, lib, ... }:
{
  config = lib.mkIf config.services.rabbitmq.enable {
    services.rabbitmq = {
      listenAddress = "0.0.0.0";
      configItems = {
        "load_definitions" = config.age.secrets.rabbitmqDefinitions.path;
        "listeners.ssl.default" = "5671";
        "ssl_options.cacertfile" = "/var/rabbitmq_crt/ca.crt";
        "ssl_options.certfile" = "/var/rabbitmq_crt/server.crt";
        "ssl_options.keyfile" = "/var/rabbitmq_crt/server.key";
        "ssl_options.verify" = "verify_peer";
        "ssl_options.fail_if_no_peer_cert" = "true";
      };
    };
    networking.firewall.allowedTCPPorts = [ 5671 ];
    age.secrets.rabbitmqDefinitions = {
      file = ../../secrets/rabbitmq-definitions.age;
      owner = "rabbitmq";
      group = "rabbitmq";
      mode = "400";
    };
  };
}
