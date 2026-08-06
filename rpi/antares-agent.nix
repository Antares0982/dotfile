{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Its own unix user, not `antares`. F19 measured that the bubblewrap sandbox
  # blocks writes outside cwd but not *reads*, so every file the service user
  # can read is readable by the agent. Deny rules cover the known credential
  # paths, but they are a soft guard inside the CLI; a separate uid is the only
  # boundary the kernel enforces. Homes on this machine are already 0700, so
  # /home/antares becomes unreachable for free.
  user = "agent";
  group = "agent";
  home = "/home/${user}";

  # Constant cwd for every session (D2). The CLI derives its session directory
  # from cwd -- ~/.claude/projects/-home-agent-agent-work -- so moving this
  # orphans every resumable thread.
  workspace = "${home}/agent_work";

  # uv + venv, not Nix. The Agent SDK wheel carries its own `claude` binary and
  # the two are version-matched; packaging the python side would mean an
  # aarch64 rebuild for every patch bump. Deployed out of band:
  #
  #     sudo -u agent git clone <repo> ${home}/app
  #     sudo -u agent sh -c 'cd ${home}/app && uv sync'
  #
  # Bound read-only into the unit below: the agent must not be able to edit the
  # code that decides what the agent may do.
  appDir = "${home}/app";

  stateDir = "/var/lib/antares-agent";

  # F23 is the one failure mode in this design where the configuration looks
  # entirely correct and the security boundary simply is not there: with either
  # bwrap or socat missing from PATH the SDK logs one warning line, leaves
  # sandbox.enabled true, and enforces nothing. The process self-checks at
  # startup and refuses to run, but it can only pass if both are here.
  runtimePath = with pkgs; [
    bubblewrap
    socat

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

  launcher = pkgs.writeShellApplication {
    name = "antares-agent-launch";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # Pin the CLI rather than inherit _find_cli()'s resolution order, which
      # prefers the wheel's bundled binary over PATH anyway but silently (F9).
      # Globbed rather than hard-coded: the interpreter version in the venv
      # path changes with nixpkgs, and a stale literal would fail late.
      shopt -s nullglob
      candidates=(${appDir}/.venv/lib/python*/site-packages/claude_agent_sdk/_bundled/claude)
      if [ ''${#candidates[@]} -eq 0 ]; then
        echo "no bundled claude under ${appDir}/.venv -- run 'uv sync' first" >&2
        exit 1
      fi
      ANTARES_CLI_PATH="''${candidates[0]}"
      export ANTARES_CLI_PATH

      exec ${appDir}/.venv/bin/python -m antares_agent
    '';
  };
in
{
  # The bundled `claude` is a generic-linux aarch64 ELF asking for
  # /lib/ld-linux-aarch64.so.1, which does not exist on NixOS. nix-ld supplies
  # it. The alternative measured in F13 -- patchelf --set-interpreter -- works
  # but bakes in a glibc store path that gets GC'd on the next system upgrade,
  # and has to be redone after every `uv sync`.
  #
  # nixpkgs' own claude-code was the third option and is rejected: this host's
  # pin carries 2.1.81, roughly 140 releases behind the SDK, and aarch64 has no
  # cache hit for it (~15 min build).
  programs.nix-ld.enable = true;

  users.groups.${group} = { };
  users.users.${user} = {
    isNormalUser = true;
    inherit home group;
    description = "antares-agent runtime";
    useDefaultShell = true;
  };

  # BindPaths= below needs each source to exist on the host, so these are
  # created before the unit runs rather than by the service itself.
  systemd.tmpfiles.rules = [
    "d ${workspace} 0750 ${user} ${group} - -"
    "d ${workspace}/.agent 0750 ${user} ${group} - -"
    "d ${home}/.claude 0700 ${user} ${group} - -"
    "d ${appDir} 0755 ${user} ${group} - -"
  ];

  systemd.services.antares-agent = {
    description = "antares-agent: persistent multi-repo coding agent";
    after = [
      "network-online.target"
      "xray.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = runtimePath ++ [ "/run/current-system/sw" ];

    environment = {
      HOME = home;
      ANTARES_WORKSPACE = workspace;
      ANTARES_HOST = "127.0.0.1";
      ANTARES_PORT = "60001";
      # Kept out of the workspace: everything under cwd is writable by the
      # agent, and its own event log and thread store should not be.
      ANTARES_DB_PATH = "${stateDir}/antares.db";
      ANTARES_PROFILES_DIR = "${stateDir}/profiles";

      # The CLI's own model requests go through the local proxy; sandboxed Bash
      # cannot reach it (F22 measured the asymmetry).
      http_proxy = "http://127.0.0.1:1081";
      https_proxy = "http://127.0.0.1:1081";
    };

    serviceConfig = {
      Type = "exec";
      User = user;
      Group = group;
      WorkingDirectory = workspace;
      ExecStart = "${launcher}/bin/antares-agent-launch";
      EnvironmentFile = config.age.secrets.antaresAgentEnv.path;

      StateDirectory = "antares-agent";
      StateDirectoryMode = "0750";

      # V1: a process that dies with an approval pending leaves a consistent
      # session -- the CLI synthesises the pending tool into a tool failure and
      # closes the turn. Restarting is safe; the resumed thread just needs a
      # nudge to retry.
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStopSec = "60s";
      # KillMode is deliberately left at the default control-group. F1: when
      # the parent is killed on its own, orphaned `claude` children keep making
      # model requests, so every restart would otherwise accumulate another
      # batch of them burning quota.

      # V4: ~218MB PSS for the first live client and ~123MB for each further
      # one, and this Pi has ~4GB free. The pool is capped at 6 in the
      # application; this is the backstop for when a session's context grows.
      MemoryHigh = "2G";
      MemoryMax = "3G";

      # Measured against bwrap on this machine (F12). Only two of these needed
      # a special spelling; the rest are free.
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      # `claude` is a Bun binary; probed under this setting it still runs
      # (2.1.222 reported --version cleanly), so the JIT tolerates W^X.
      MemoryDenyWriteExecute = true;

      # Not a list, and not "yes": RestrictNamespaces=user reads like "permit
      # user" but means "permit *only* user", and bwrap --unshare-all needs
      # every one of these. Dropping mnt alone is enough to break it.
      RestrictNamespaces = "user mnt pid net ipc uts cgroup";
      # @system-service excludes mount/pivot_root/umount2, so bwrap dies of
      # SIGSYS without @mount.
      SystemCallFilter = "@system-service @mount";

      # tmpfs rather than read-only: read-only would still leave every other
      # home on this box readable, which is exactly the F19 exposure. The three
      # paths the service actually needs come back explicitly.
      ProtectHome = "tmpfs";
      BindPaths = [
        workspace
        "${home}/.claude"
      ];
      BindReadOnlyPaths = [ appDir ];
    };
  };
}
