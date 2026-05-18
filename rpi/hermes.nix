{
  config,
  pkgs,
  lib,
  hermes-agent-pkg,
  hermes-antares-bridge-pkg,
  ...
}:
let
  shellenv = import ../common/shellEnv.nix;
  hermesHome = "/home/hermes";
  hermesConfigDir = "${hermesHome}/.hermes";

  # ---- 核心: 将 bridge 叠加到 hermes-agent 内置插件目录 ----
  hermes-agent = pkgs.runCommand "hermes-agent-with-bridge" { } ''
    cp -r ${hermes-agent-pkg} $out
    chmod -R +w $out
    ln -sf ${hermes-antares-bridge-pkg} $out/share/hermes-agent/plugins/platforms/antares
    sed -i "s|${hermes-agent-pkg}|$out|g" $out/bin/hermes
  '';

  # ---- config.yaml ----
  configYaml = pkgs.writeText "hermes-config.yaml" ''
    gateway:
      platforms:
        antares:
          enabled: true
          extra:
            rabbitmq_host: "chr.fan"
            rabbitmq_port: 5671
            rabbitmq_user: "hermes"
            rabbitmq_vhost: "remotecall"
            rabbitmq_cafile: "/run/agenix/hermesRabbitCa"
            rabbitmq_certfile: "/run/agenix/hermesRabbitCert"
            rabbitmq_keyfile: "/run/agenix/hermesRabbitKey"

    agent:
      gateway_timeout: 1800
      max_iterations: 90

    terminal:
      cwd: "/home/hermes"

    display:
      background_process_notifications: "result"
  '';
in
{
  systemd.services."hermes-gateway" = {
    description = "Hermes Agent Gateway Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      mkdir -p ${hermesConfigDir}
      install -o hermes -g users -m 0640 ${configYaml} ${hermesConfigDir}/config.yaml
    '';

    environment = {
      HERMES_HOME = hermesConfigDir;
      ANTARES_RABBITMQ_HOST = "chr.fan";
      ANTARES_RABBITMQ_PORT = "5671";
      ANTARES_RABBITMQ_USER = "hermes";
      ANTARES_RABBITMQ_VHOST = "remotecall";
      ANTARES_RABBITMQ_CAFILE = "/run/agenix/hermesRabbitCa";
      ANTARES_RABBITMQ_CERTFILE = "/run/agenix/hermesRabbitCert";
      ANTARES_RABBITMQ_KEYFILE = "/run/agenix/hermesRabbitKey";
    };

    serviceConfig = {
      User = "hermes";
      Group = "users";
      WorkingDirectory = hermesHome;
      Restart = "always";
      RestartSec = "10";
      TimeoutStopSec = "300";
      LoadCredential = [
        "hermes-env:/run/agenix/hermesEnv"
      ];
    };

    script = ''
      export PATH=$PATH:${shellenv.sysBin}
      if [ -f "$CREDENTIALS_DIRECTORY/hermes-env" ]; then
        set -a
        source "$CREDENTIALS_DIRECTORY/hermes-env"
        set +a
      fi
      ${hermes-agent}/bin/hermes gateway
    '';
  };
}
