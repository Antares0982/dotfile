{
  config,
  lib,
  pkgs,
  ...
}:
let
  pyenv = pkgs.python3.withPackages (
    ps: with ps; [
      aio-pika
      websockets
    ]
  );
  qqRelay = pkgs.writeShellApplication {
    name = "qq-napcat-relay";
    runtimeInputs = [ pyenv ];
    text = ''
      exec python3 ${./qq-relay/qq_napcat_relay.py}
    '';
  };
in
{
  systemd.services.qq-napcat-relay = {
    description = "QQ-NapCat RabbitMQ Relay";
    after = [
      "network.target"
      "network-online.target"
      "napcat.service"
      "rabbitmq.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "napcat";
      ExecStart = "${qqRelay}/bin/qq-napcat-relay";
      Restart = "always";
      RestartSec = "10s";
      EnvironmentFile = config.age.secrets.qqRelayEnv.path;
    };
    environment = {
      RMQ_CAFILE = config.age.secrets.qqRelayRabbitCa.path;
      RMQ_CERTFILE = config.age.secrets.qqRelayRabbitCert.path;
      RMQ_KEYFILE = config.age.secrets.qqRelayRabbitKey.path;
    };
  };
}
