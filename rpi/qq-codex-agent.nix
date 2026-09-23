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
  home = "${work}/.home";
  app = qq-codex-agent;
  ghToken = "/etc/qq-codex-agent/gh-token";
  launcher = pkgs.writeShellScript "qq-codex-launch" ''
    set -eu
    export GH_TOKEN="$(${pkgs.coreutils}/bin/cat ${ghToken})"
    exec ${app}/bin/qq-codex-agent
  '';
  threadCheck = pkgs.writeText "qq-codex-thread-check.py" ''
    import asyncio
    import os
    import subprocess
    import tempfile
    from pathlib import Path

    from codex_cli_bin import bundled_codex_path
    from openai_codex import ApprovalMode, AsyncCodex, Sandbox
    from qq_codex_agent import Settings, codex_config

    async def main():
        settings = Settings.load("/etc/qq-codex-agent/config.toml")
        async with asyncio.timeout(30):
            with tempfile.TemporaryDirectory(dir=settings.workspace_dir) as directory:
                Path(directory, "flake.nix").write_text(
                    '{ outputs = { self }: { apps.${pkgs.stdenv.hostPlatform.system}.hello = '
                    '{ type = "app"; program = "${pkgs.hello}/bin/hello"; }; }; }'
                )
                subprocess.run(["git", "init", "-q", directory], check=True)
                subprocess.run(["git", "-C", directory, "add", "flake.nix"], check=True)
                async with AsyncCodex(config=codex_config(settings)) as codex:
                    await codex.thread_start(
                        cwd=directory,
                        sandbox=Sandbox.workspace_write,
                        approval_mode=ApprovalMode.auto_review,
                        ephemeral=True,
                        config={"projects": {directory: {"trust_level": "trusted"}}},
                    )
                subprocess.run(
                    [
                        str(bundled_codex_path()),
                        "-c",
                        'sandbox_mode="workspace-write"',
                        "-c",
                        'approval_policy="on-request"',
                        "-c",
                        'approvals_reviewer="auto_review"',
                        "sandbox",
                        "--",
                        "/bin/sh",
                        "-ec",
                        'test ! -r ${ghToken}; '
                        'for tool in git gh uv nix; do command -v "$tool"; "$tool" --version >/dev/null; done; '
                        'test "$(nix run --offline "git+file://$PWD#hello")" = "Hello, world!"',
                    ],
                    cwd=directory,
                    env={**os.environ, "CODEX_HOME": str(settings.state_dir / "codex")},
                    timeout=30,
                    check=True,
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
      gh
      uv
      nix
      ripgrep
      python313
      bubblewrap
      cacert
    ];
  };
  codexConfig = pkgs.writeText "qq-codex-codex-config.toml" ''
    model_provider = "openai-http"

    [model_providers.openai-http]
    name = "OpenAI"
    base_url = "https://chatgpt.com/backend-api/codex"
    wire_api = "responses"
    requires_openai_auth = true
    supports_websockets = false

    [sandbox_workspace_write]
    network_access = true
    writable_roots = ["${work}/.uv", "${home}"]
  '';
  nsswitch = pkgs.writeText "qq-codex-nsswitch.conf" "hosts: files dns\n";
  configFile = (pkgs.formats.toml { }).generate "qq-codex-config.toml" {
    allowlist_file = "/etc/qq-codex-agent/allowlist.toml";
    napcat_url = cfg.napcatUrl;
    token_file = "/etc/qq-codex-agent/napcat-token";
    state_dir = state;
    workspace_dir = work;
    agents_file = "/etc/qq-codex-agent/AGENTS.md";
    private_agents_file = "/etc/qq-codex-agent/AGENTS.private.md";
    group_agents_file = "/etc/qq-codex-agent/AGENTS.group.md";
    queue_limit = 8;
    task_timeout = 900;
  };
  requirements = pkgs.writeText "qq-codex-requirements.toml" ''
    allowed_approval_policies = ["on-request"]
    allowed_approvals_reviewers = ["auto_review"]
    allowed_sandbox_modes = ["workspace-write", "read-only"]
    allow_login_shell = false
    [permissions.filesystem]
    deny_read = ["${state}", "/etc/qq-codex-agent/napcat-token", "/etc/qq-codex-agent/allowlist.toml", "${ghToken}"]
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
      "/nix/store"
      "/nix/var/nix/daemon-socket"
      "${state}/codex/tmp/arg0"
      "${configFile}:/etc/qq-codex-agent/config.toml"
      "${config.age.secrets.qqCodexAllowlist.path}:/etc/qq-codex-agent/allowlist.toml"
      "${config.age.secrets.qqCodexGhToken.path}:${ghToken}"
      "${cfg.agentsFile}:/etc/qq-codex-agent/AGENTS.md"
      "${cfg.agentsFile}:${state}/codex/AGENTS.md"
      "/etc/qq-codex-agent/AGENTS.private.md:/etc/qq-codex-agent/AGENTS.private.md"
      "/etc/qq-codex-agent/AGENTS.group.md:/etc/qq-codex-agent/AGENTS.group.md"
      "${codexConfig}:${state}/codex/config.toml"
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
    HOME = home;
    PATH = lib.mkForce "${work}/.uv/bin:${runtime}/bin";
    XDG_CONFIG_HOME = "/tmp/qq-codex-config";
    XDG_CACHE_HOME = "/tmp/qq-codex-cache";
    UV_CACHE_DIR = "${work}/.uv/cache";
    UV_PYTHON_INSTALL_DIR = "${work}/.uv/python";
    UV_PYTHON_BIN_DIR = "${work}/.uv/bin";
    NIX_REMOTE = "daemon";
    NIX_CONFIG = "experimental-features = nix-command flakes";
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
    age.secrets.qqCodexGhToken = {
      file = ../secrets/qq-codex-gh-token.age;
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
      "d ${home} 0700 ${user} ${user} -"
      "d ${work}/.uv 0700 ${user} ${user} -"
      "d /etc/qq-codex-agent 0750 root ${user} -"
      "C /etc/qq-codex-agent/AGENTS.md 0640 root ${user} - ${app}/share/qq-codex-agent/AGENTS.md"
      "C /etc/qq-codex-agent/AGENTS.private.md 0640 root ${user} - ${app}/share/qq-codex-agent/AGENTS.private.md"
      "C /etc/qq-codex-agent/AGENTS.group.md 0640 root ${user} - ${app}/share/qq-codex-agent/AGENTS.group.md"
    ];
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
        config.age.secrets.qqCodexGhToken.file
      ];
      wants = [ "network-online.target" ];
      inherit environment;
      serviceConfig = serviceConfig // {
        ExecStartPre = [
          "${app}/bin/qq-codex-check"
          "${app}/bin/qq-codex-python ${threadCheck}"
        ];
        ExecStart = "${launcher}";
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
