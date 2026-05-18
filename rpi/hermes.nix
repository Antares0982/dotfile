{
  config,
  pkgs,
  lib,
  hermes-agent-pkg,
  hermes-agent-module,
  hermes-antares-bridge-pkg,
  ...
}:
{
  imports = [ hermes-agent-module ];

  services.hermes-agent = {
    enable = true;
    package = hermes-agent-pkg;
    createUser = false;
    user = "hermes";
    group = "users";
    stateDir = "/home/hermes";
    workingDirectory = "/home/hermes";

    settings = {
      gateway = {
        platforms = {
          antares = {
            enabled = true;
            extra = {
              rabbitmq_host = "chr.fan";
              rabbitmq_port = 5671;
              rabbitmq_user = "hermes";
              rabbitmq_vhost = "remotecall";
              rabbitmq_cafile = "/run/agenix/hermesRabbitCa";
              rabbitmq_certfile = "/run/agenix/hermesRabbitCert";
              rabbitmq_keyfile = "/run/agenix/hermesRabbitKey";
            };
          };
        };
      };
      agent = {
        gateway_timeout = 1800;
        max_iterations = 90;
      };
      terminal = {
        cwd = "/home/hermes";
      };
      display = {
        background_process_notifications = "result";
      };
    };

    environment = {
      ANTARES_RABBITMQ_HOST = "chr.fan";
      ANTARES_RABBITMQ_PORT = "5671";
      ANTARES_RABBITMQ_USER = "hermes";
      ANTARES_RABBITMQ_VHOST = "remotecall";
      ANTARES_RABBITMQ_CAFILE = "/run/agenix/hermesRabbitCa";
      ANTARES_RABBITMQ_CERTFILE = "/run/agenix/hermesRabbitCert";
      ANTARES_RABBITMQ_KEYFILE = "/run/agenix/hermesRabbitKey";
    };

    environmentFiles = [
      config.age.secrets.hermesEnv.path
    ];

    extraPlugins = [ hermes-antares-bridge-pkg ];

    restart = "always";
    restartSec = 10;
  };
}
