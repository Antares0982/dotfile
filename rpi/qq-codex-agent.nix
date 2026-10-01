{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  user = "qq-codex-agent";
  app = config.services.qq-codex-agent.package;
  ghToken = "/etc/qq-codex-private/gh-token";
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
  environment = {
    http_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
    https_proxy = lib.mkIf config.antares.proxy.enable config.antares.proxy.httpUrl;
    no_proxy = "127.0.0.1,localhost,::1";
    NIX_REMOTE = "daemon";
    NIX_CONFIG = "experimental-features = nix-command flakes";
  };
  mounts = [
    "/nix/store"
    "/nix/var/nix/daemon-socket"
    "${config.age.secrets.qqCodexGhToken.path}:${ghToken}"
  ];
in
{
  imports = [ (inputs.qq-codex-agent + "/nix/module.nix") ];
  config = lib.mkIf config.services.qq-codex-agent.enable {
    assertions = [
      {
        assertion = config.services.napcat.enable;
        message = "QQ Codex requires services.napcat.enable.";
      }
    ];
    services.qq-codex-agent = {
      package = import (inputs.qq-codex-agent + "/nix/package.nix") {
        inherit inputs;
        system = pkgs.stdenv.hostPlatform.system;
      };
      allowlistFile = config.age.secrets.qqCodexAllowlist.path;
      tokenFile = "/run/qq-codex-auth/token";
      authSocket = "/run/codex-auth/auth.sock";
      extraPackages = [
        pkgs.gh
        pkgs.nix
      ];
      codexSettings = {
        model_provider = "openai-http";
        model_providers.openai-http = {
          name = "OpenAI";
          base_url = "https://chatgpt.com/backend-api/codex";
          wire_api = "responses";
          requires_openai_auth = true;
          supports_websockets = false;
        };
      };
    };
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
    system.activationScripts.qqCodexRestart = {
      deps = [ "agenix" ];
      text = ''
        mkdir -p /run/nixos
        echo qq-codex-agent.service >> /run/nixos/activation-restart-list
      '';
    };
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
      after = [
        "napcat.service"
        "qq-codex-auth.service"
      ]
      ++ lib.optional config.antares.xray.enable "xray.service";
      requires = [ "qq-codex-auth.service" ];
      restartTriggers = [
        config.age.secrets.qqRelayEnv.file
        config.age.secrets.qqCodexAllowlist.file
        config.age.secrets.qqCodexGhToken.file
      ];
      inherit environment;
      serviceConfig = {
        ExecStart = lib.mkForce "${launcher}";
        ExecStartPre = lib.mkAfter [ "${app}/bin/qq-codex-python ${threadCheck}" ];
        BindReadOnlyPaths = mounts;
      };
    };

  };
}
