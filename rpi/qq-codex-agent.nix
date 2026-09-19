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
  threadCheck = pkgs.writeText "qq-codex-thread-check.py" ''
    import asyncio
    import tempfile

    from openai_codex import ApprovalMode, AsyncCodex, Sandbox
    from qq_codex_agent import Settings, codex_config

    async def main():
        settings = Settings.load("/etc/qq-codex-agent/config.toml")
        async with asyncio.timeout(30):
            with tempfile.TemporaryDirectory(dir=settings.workspace_dir) as directory:
                async with AsyncCodex(config=codex_config(settings)) as codex:
                    await codex.thread_start(
                        cwd=directory,
                        sandbox=Sandbox.workspace_write,
                        approval_mode=ApprovalMode.auto_review,
                        ephemeral=True,
                        config={"projects": {directory: {"trust_level": "trusted"}}},
                    )
        print("Codex thread startup check passed")

    asyncio.run(main())
  '';
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
      threadCheck
      pkgs.python313
      pkgs.glibcLocales
      pkgs.tzdata
    ];
  };
  nsswitch = pkgs.writeText "qq-codex-nsswitch.conf" "hosts: files dns\n";
  configFile = (pkgs.formats.toml { }).generate "qq-codex-config.toml" {
    allowlist_file = "/etc/qq-codex-agent/allowlist.toml";
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
    deny_read = ["${state}", "/etc/qq-codex-agent/napcat-token", "/etc/qq-codex-agent/allowlist.toml"]
  '';
  generator = pkgs.writeShellScript "qq-codex-mounts" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p "$1/qq-codex-agent.service.d" "$1/qq-codex-login.service.d"
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
      "${state}/codex/tmp/arg0"
      "${configFile}:/etc/qq-codex-agent/config.toml"
      "${config.age.secrets.qqCodexAllowlist.path}:/etc/qq-codex-agent/allowlist.toml"
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
    napcatUrl = lib.mkOption {
      type = lib.types.str;
      default = "ws://127.0.0.1:3001";
    };
    agentsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/qq-codex-agent/AGENTS.md";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets.qqCodexAllowlist = {
      file = ../secrets/qq-codex-allowlist.age;
      owner = user;
      group = user;
      mode = "0400";
    };
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
      "d ${state}/codex/tmp/arg0 0700 ${user} ${user} -"
      "d ${work} 0700 ${user} ${user} -"
      "d /etc/qq-codex-agent 0750 root ${user} -"
      "C /etc/qq-codex-agent/AGENTS.md 0640 root ${user} - ${app}/share/qq-codex-agent/AGENTS.md"
    ];
    systemd.generators.qq-codex-mounts = generator;
    systemd.services.qq-codex-auth = {
      description = "QQ Codex NapCat credentials";
      restartTriggers = [ config.age.secrets.qqRelayEnv.file ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        Group = user;
        EnvironmentFile = config.age.secrets.qqRelayEnv.path;
        RuntimeDirectory = "qq-codex-auth";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
      script = ''
        printf '%s' "''${NAPCAT_WS_TOKEN-}" > /run/qq-codex-auth/token
      '';
    };
    systemd.services.qq-codex-agent = {
      description = "QQ Codex agent";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "napcat.service"
        "xray.service"
        "qq-codex-auth.service"
      ];
      requires = [ "qq-codex-auth.service" ];
      restartTriggers = [
        config.age.secrets.qqRelayEnv.file
        config.age.secrets.qqCodexAllowlist.file
      ];
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = serviceConfig // {
        ExecStartPre = [
          "${app}/bin/qq-codex-check"
          "${app}/bin/qq-codex-python ${threadCheck}"
        ];
        ExecStart = "${app}/bin/qq-codex-agent";
        BindReadOnlyPaths = serviceConfig.BindReadOnlyPaths ++ [
          "/run/qq-codex-auth/token:/etc/qq-codex-agent/napcat-token"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
    systemd.services.qq-codex-login = {
      description = "QQ Codex device login";
      conflicts = [ "qq-codex-agent.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = serviceConfig // {
        ExecStart = "${app}/bin/qq-codex-agent --login";
        Restart = "no";
      };
    };
  };
}
