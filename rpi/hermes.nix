{
  config,
  lib,
  pkgs,
  hermes-agent,
  ...
}:
{
  imports = [ hermes-agent.nixosModules.default ];

  users.groups.hermes = { };

  services.hermes-agent = {
    enable = true;
    createUser = false;
    stateDir = "/home/hermes";
    workingDirectory = "/home/hermes/workspace";

    environmentFiles = [
      config.age.secrets.hermesEnv.path
    ];

    environment = {
      ANTARES_RABBITMQ_CAFILE = config.age.secrets.hermesRabbitCa.path;
      ANTARES_RABBITMQ_CERTFILE = config.age.secrets.hermesRabbitCert.path;
      ANTARES_RABBITMQ_KEYFILE = config.age.secrets.hermesRabbitKey.path;
    };
    extraPackages = with pkgs; [
      python3
      uv
      clang
      cmake
      ninja
      pkg-config
      valgrind
      wget
      fzf
      bat
    ];

    settings = {
      security.redact_secrets = true;
    };
  };
}
