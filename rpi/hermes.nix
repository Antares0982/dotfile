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

  # systemd drain_timeout=180s → TimeoutStopSec must be >= 180+30=210
  systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = lib.mkForce "210";

  # The hermes-agent NixOS module builds the systemd PATH from Nix store
  # paths only.  Prepend /run/current-system/sw so tools installed via
  # environment.systemPackages (gh, nix, cachix, ...) are visible.
  systemd.services.hermes-agent.path = lib.mkBefore [ "/run/current-system/sw" ];
}
