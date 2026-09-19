{
  config,
  lib,
  pkgs,
  qq-codex-agent,
  ...
}:
let
  cfg = config.services.qq-codex-agent;
  user = "qq-codex-agent";
  state = "/var/lib/qq-codex-agent";
  work = "/var/lib/qq-codex-work";
  app = qq-codex-agent;
  runtime = pkgs.buildEnv {
    name = "qq-codex-runtime";
    paths = with pkgs; [
      bash
      coreutils
      git
      ripgrep
      python313
      bubblewrap
      cacert
    ];
  };
  closure = pkgs.closureInfo {
    rootPaths = [
      runtime
      app
      pkgs.python313
      pkgs.glibcLocales
      pkgs.tzdata
    ];
  };
  nsswitch = pkgs.writeText "qq-codex-nsswitch.conf" "hosts: files dns\n";
  configFile = (pkgs.formats.toml { }).generate "qq-codex-config.toml" {
    allowed_users = cfg.allowedUsers;
    allowed_groups = cfg.allowedGroups;
    napcat_url = cfg.napcatUrl;
    token_file = "/etc/qq-codex-agent/napcat-token";
    state_dir = state;
    workspace_dir = work;
    agents_file = "/etc/qq-codex-agent/AGENTS.md";
    queue_limit = 8;
    task_timeout = 900;
  };
  requirements = pkgs.writeText "qq-codex-requirements.toml" ''
    allowed_approval_policies = ["on-request"]
    allowed_approvals_reviewers = ["auto_review"]
    allowed_sandbox_modes = ["workspace-write", "read-only"]
    [permissions.filesystem]
    deny_read = ["${state}", "/etc/qq-codex-agent/napcat-token"]
  '';
  generator = pkgs.writeShellScript "qq-codex-mounts" ''
    set -eu
    mkdir -p "$1/qq-codex-agent.service.d" "$1/qq-codex-login.service.d"
    for unit in qq-codex-agent qq-codex-login; do
      {
        echo '[Service]'
        while IFS= read -r storePath; do
          printf 'BindReadOnlyPaths=%s\n' "$storePath"
        done < ${closure}/store-paths
      } > "$1/$unit.service.d/runtime.conf"
    done
  '';
  serviceConfig = {
    Type = "exec";
    User = user;
    Group = user;
    RootDirectory = "/var/lib/qq-codex-root";
    MountAPIVFS = true;
    WorkingDirectory = work;
    StateDirectory = [
      "qq-codex-agent"
      "qq-codex-work"
    ];
    StateDirectoryMode = "0700";
    UMask = "0077";
    BindReadOnlyPaths = [
      "${configFile}:/etc/qq-codex-agent/config.toml"
      "${cfg.agentsFile}:/etc/qq-codex-agent/AGENTS.md"
      "${cfg.agentsFile}:${state}/codex/AGENTS.md"
      "${requirements}:/etc/codex/requirements.toml"
      "${pkgs.bash}/bin/bash:/bin/sh"
      "${pkgs.coreutils}/bin/env:/usr/bin/env"
      "${nsswitch}:/etc/nsswitch.conf"
      "/etc/resolv.conf:/etc/resolv.conf"
      "/etc/hosts:/etc/hosts"
    ];
    BindPaths = [
      state
      work
    ];
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    NoNewPrivileges = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = "user mnt pid net ipc uts cgroup";
    CapabilityBoundingSet = "";
    MemoryHigh = "1G";
    MemoryMax = "2G";
    TasksMax = 256;
    TimeoutStopSec = "30s";
    KillMode = "control-group";
  };
  environment = {
    HOME = state;
    PATH = lib.mkForce "${runtime}/bin";
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
    no_proxy = "127.0.0.1,localhost,::1";
  };
in
{
  options.services.qq-codex-agent = {
    enable = lib.mkEnableOption "personal QQ Codex agent";
    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    allowedGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    napcatUrl = lib.mkOption {
      type = lib.types.str;
      default = "ws://127.0.0.1:3001";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/qq-codex-agent/napcat-token";
    };
    agentsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/qq-codex-agent/AGENTS.md";
    };
  };
  config = lib.mkIf cfg.enable {
    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = state;
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/qq-codex-root 0755 root root -"
      "d ${state} 0700 ${user} ${user} -"
      "d ${state}/codex 0700 ${user} ${user} -"
      "d ${work} 0700 ${user} ${user} -"
      "d /etc/qq-codex-agent 0750 root ${user} -"
      "C /etc/qq-codex-agent/AGENTS.md 0640 root ${user} - ${app}/share/qq-codex-agent/AGENTS.md"
    ];
    systemd.generators.qq-codex-mounts = generator;
    systemd.services.qq-codex-agent = {
      description = "QQ Codex agent";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "napcat.service"
        "xray.service"
      ];
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = serviceConfig // {
        ExecStartPre = "${app}/bin/qq-codex-check";
        ExecStart = "${app}/bin/qq-codex-agent";
        BindReadOnlyPaths = serviceConfig.BindReadOnlyPaths ++ [
          "${cfg.tokenFile}:/etc/qq-codex-agent/napcat-token"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
    systemd.services.qq-codex-login = {
      description = "QQ Codex device login";
      conflicts = [ "qq-codex-agent.service" ];
      after = [ "network-online.target" ];
      inherit environment;
      serviceConfig = serviceConfig // {
        ExecStart = "${app}/bin/qq-codex-agent --login";
        Restart = "no";
      };
    };
  };
}
