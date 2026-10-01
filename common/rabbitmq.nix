{ config, lib, ... }:
{
  config = lib.mkIf config.services.rabbitmq.enable {
    services.rabbitmq = {
      listenAddress = lib.mkDefault "127.0.0.1";
      managementPlugin.enable = true;
    };
  };
}
