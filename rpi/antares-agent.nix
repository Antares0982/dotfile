{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = "agent";
  group = "agent";
  home = "/home/${user}";

  relayUser = "agent-relay";

  runtimeDir = "antares-agent";
  socketPath = "/run/${runtimeDir}/api.sock";

  workspace = "${home}/agent_work";

  appDir = "${home}/app";

  stateDir = "/var/lib/antares-agent";

  runtimePath = with pkgs; [
    bubblewrap

    git
    ripgrep
    fd
    jq
    uv
    python3

    coreutils
    findutils
    gnugrep
    gnused
    gnutar
    gawk
    gzip
    diffutils
    less
    which
  ];

  updater = pkgs.writeShellApplication {
    name = "antares-agent-update";
    runtimeInputs = with pkgs; [
      git
      uv
    ];
    text = ''
      git -C ${appDir} pull --ff-only ||
        echo "git pull failed -- starting on the checked-out tree" >&2

      uv sync --project ${appDir} --extra relay
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "antares-agent-launch";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      exec ${appDir}/.venv/bin/python -m antares_agent
    '';
  };

  mountsFile = "/etc/antares-agent/mounts";

  mountGenerator = pkgs.writeShellScript "antares-agent-mounts-generator" ''
    set -eu
    [ -n "''${1:-}" ] || exit 0
    [ -r ${mountsFile} ] || exit 0

    dir="$1/antares-agent.service.d"
    mkdir -p "$dir"
    {
      echo "[Service]"
      while read -r line; do
        case "$line" in "" | "#"*) continue ;; esac
        key=BindReadOnlyPaths
        case "$line" in
          rw:*) key=BindPaths; line="''${line#rw:}" ;;
          ro:*) line="''${line#ro:}" ;;
        esac
        case "$line" in /*) ;; *) line="${home}/$line" ;; esac
        echo "$key=-$line"
      done < ${mountsFile}
    } > "$dir/mounts.conf"
  '';

  codexConfig = (pkgs.formats.toml { }).generate "antares-codex-config.toml" {
    model_provider = "openai-http";
    model_providers.openai-http = {
      name = "OpenAI";
      base_url = "https://chatgpt.com/backend-api/codex";
      wire_api = "responses";
      requires_openai_auth = true;
      supports_websockets = false;
    };
  };

  requirements = (pkgs.formats.toml { }).generate "antares-codex-requirements.toml" {
    allowed_approval_policies = [ "on-request" ];
    allowed_approvals_reviewers = [ "auto_review" ];
    allowed_sandbox_modes = [
      "read-only"
      "workspace-write"
    ];
    allow_login_shell = false;
    permissions.filesystem.deny_read = [
      stateDir
      "/run/codex-auth"
      "/run/agenix.d"
      "${home}/.ssh"
      "${home}/.gnupg"
      "${home}/.config/gh"
    ];
  };

  relayLauncher = pkgs.writeShellApplication {
    name = "antares-agent-relay-launch";
    runtimeInputs = [ ];
    text = ''
      exec ${appDir}/.venv/bin/python -m antares_agent.relay
    '';
  };
in
{
  options.antares.agent.enable = lib.mkEnableOption "Antares agent and relay";
  config = lib.mkIf (config.antares.agent.enable) {

    programs.nix-ld.enable = true;

    environment.systemPackages = with pkgs; [
      bubblewrap
    ];

    users.groups.${group} = { };
    users.users.${user} = {
      isNormalUser = true;
      inherit home group;
      description = "antares-agent runtime";
      extraGroups = [ "codex-auth-clients" ];
      useDefaultShell = true;
    };

    users.users.${relayUser} = {
      isSystemUser = true;
      group = "users";
      extraGroups = [ group ];
      description = "antares-agent bus relay";
    };

    systemd.generators.antares-agent-mounts = mountGenerator;

    systemd.tmpfiles.rules = [
      "d ${workspace} 0750 ${user} ${group} - -"
      "d ${workspace}/.agent 0750 ${user} ${group} - -"
      "d ${stateDir}/codex-v1 0700 ${user} ${group} - -"
      "d ${stateDir}/codex-v1/codex 0700 ${user} ${group} - -"
      "d ${stateDir}/codex-v1/codex/tmp/arg0 0700 ${user} ${group} - -"
      "d ${appDir} 0755 ${user} ${group} - -"
      "d /etc/antares-agent 0755 root root - -"
      "f ${mountsFile} 0644 root root - # 一行一个路径，相对 ${home}；前缀 rw: 表示可写。改完 systemctl daemon-reload && systemctl restart antares-agent\\n"
    ];

    systemd.services.antares-agent-update = {
      description = "antares-agent: pull and sync the app before starting";
      before = [ "antares-agent.service" ];
      wantedBy = [ "antares-agent.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = home;
        http_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
        https_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
      };

      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = group;
        ExecStart = "${updater}/bin/antares-agent-update";
        TimeoutStartSec = "15min";
      };
    };

    systemd.services.antares-agent = {
      description = "antares-agent: persistent multi-repo coding agent";
      after = [
        "network-online.target"
        "codex-auth.service"
      ]
      ++ lib.optional config.antares.xray.enable "xray.service";
      wants = [ "network-online.target" ];
      requires = [ "codex-auth.service" ];
      partOf = [ "codex-auth.service" ];
      wantedBy = [ "multi-user.target" ];

      path = runtimePath ++ [ "/run/current-system/sw" ];

      environment = {
        HOME = home;
        ANTARES_WORKSPACE = workspace;
        ANTARES_SOCKET = socketPath;
        ANTARES_DB_PATH = "${stateDir}/codex-v1/antares.db";
        ANTARES_CODEX_HOME = "${stateDir}/codex-v1/codex";
        ANTARES_RESOURCES_DIR = "/var/lib/antares-agent-resources";
        ANTARES_AUTH_SOCKET = "/run/codex-auth/auth.sock";
        ANTARES_PROFILES_DIR = "${stateDir}/codex-v1/profiles";

        http_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
        https_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
      };

      serviceConfig = {
        Type = "exec";
        User = user;
        Group = group;
        WorkingDirectory = workspace;
        ExecStart = "${launcher}/bin/antares-agent-launch";

        StateDirectory = [
          "antares-agent"
          "antares-agent-resources"
        ];
        StateDirectoryMode = "0750";

        RuntimeDirectory = runtimeDir;
        RuntimeDirectoryMode = "0750";

        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";

        MemoryHigh = "2G";
        MemoryMax = "3G";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        MemoryDenyWriteExecute = false;

        RestrictNamespaces = "user mnt pid net ipc uts cgroup";
        SystemCallFilter = "@system-service @mount";

        ProtectHome = "tmpfs";
        BindPaths = [
          workspace
          "-${home}/.gnupg"
          "-${home}/.config/gh"
        ];
        BindReadOnlyPaths = [
          appDir
          "${requirements}:/etc/codex/requirements.toml"
          "${pkgs.emptyDirectory}:${stateDir}/codex-v1/codex/tmp/arg0"
          "${codexConfig}:${stateDir}/codex-v1/codex/config.toml"
          "/run/codex-auth"
          "-${home}/.gitconfig"
        ];
      };
    };

    systemd.services.antares-agent-relay = {
      description = "antares-agent: SSE/AMQP relay";
      after = [
        "network-online.target"
        "antares-agent.service"
      ];
      wants = [ "network-online.target" ];
      bindsTo = [ "antares-agent.service" ];
      partOf = [ "antares-agent.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        ANTARES_API_SOCKET = socketPath;
        ANTARES_FILE_URL = "https://tg.alyr.dev";
        ANTARES_RELAY_STATE = "/var/lib/antares-agent-relay/codex-v1";
        RMQ_CAFILE = config.age.secrets.agentRelayRabbitCa.path;
        RMQ_CERTFILE = config.age.secrets.agentRelayRabbitCert.path;
        RMQ_KEYFILE = config.age.secrets.agentRelayRabbitKey.path;
      };

      serviceConfig = {
        Type = "exec";
        User = relayUser;
        Group = "users";
        SupplementaryGroups = [ group ];
        ExecStart = "${relayLauncher}/bin/antares-agent-relay-launch";
        Restart = "always";
        RestartSec = "10s";
        StateDirectory = "antares-agent-relay";
        StateDirectoryMode = "0700";
        EnvironmentFile = [
          config.age.secrets.agentRelayEnv.path
          config.age.secrets.agentFilesRelayEnv.path
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = "tmpfs";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallFilter = "@system-service";
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        MemoryMax = "256M";

        BindReadOnlyPaths = [ appDir ];
      };
    };

    age.secrets.agentRelayRabbitCa = {
      file = ../secrets/hermes-rabbit-ca.age;
      owner = "agent-relay";
      group = "users";
      mode = "400";
    };
    age.secrets.agentRelayRabbitCert = {
      file = ../secrets/hermes-rabbit-cert.age;
      owner = "agent-relay";
      group = "users";
      mode = "400";
    };
    age.secrets.agentRelayRabbitKey = {
      file = ../secrets/hermes-rabbit-key.age;
      owner = "agent-relay";
      group = "users";
      mode = "400";
    };
    age.secrets.agentFilesRelayEnv = {
      file = ../secrets/agent-files-relay-env.age;
      owner = "agent-relay";
      mode = "400";
    };
    age.secrets.agentRelayEnv = {
      file = ../secrets/agent-relay-env.age;
      owner = "agent-relay";
      group = "users";
      mode = "400";
    };
  };
}
