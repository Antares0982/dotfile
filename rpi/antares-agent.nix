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

  # The relay is a third uid on purpose (D12 in docs/design/04-telegram.md).
  # It holds the broker's client certificate, and by the same F19 argument that
  # gave the agent its own user, that certificate must not be readable by the
  # uid the model runs under. It joins group `agent` only to reach the socket.
  relayUser = "agent-relay";

  runtimeDir = "antares-agent";
  socketPath = "/run/${runtimeDir}/api.sock";

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

  relayLauncher = pkgs.writeShellApplication {
    name = "antares-agent-relay-launch";
    runtimeInputs = [ ];
    text = ''
      exec ${appDir}/.venv/bin/python -m antares_agent.relay
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

  # Also system-wide, not only in the unit's `path` below. The CLI runs every
  # Bash call through the login shell, and /etc/zshenv replaces PATH with the
  # system PATH before running anything -- so the unit's PATH reaches the
  # server process and nothing it spawns. Measured: `zsh:1: command not found:
  # bwrap` on every sandboxed command, while `shutil.which` in the server
  # found it fine. It fails closed, but the model reads the 127 as a broken
  # sandbox and starts asking for `dangerouslyDisableSandbox` instead.
  environment.systemPackages = with pkgs; [
    bubblewrap
    socat
  ];

  users.groups.${group} = { };
  users.users.${user} = {
    isNormalUser = true;
    inherit home group;
    description = "antares-agent runtime";
    useDefaultShell = true;
  };

  users.users.${relayUser} = {
    isSystemUser = true;
    group = "users";
    # Only so it can traverse /run/antares-agent, which is 0750 agent:agent.
    # The socket itself ends up 0666 -- uvicorn chmods it -- so the directory
    # is what actually keeps every other uid on this box out of the API.
    extraGroups = [ group ];
    description = "antares-agent bus relay";
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
      # A socket rather than a loopback port, and it replaces the port rather
      # than joining it. The API has no authentication of its own, so on a host
      # where actionrunner and ssrjsonrunner can also open sockets, a TCP
      # listener means either of them can drive the agent. Here authorisation
      # is the mode on /run/antares-agent. (F21 is about ANTHROPIC_BASE_URL not
      # parsing socket URLs; it does not apply to our own listener.)
      ANTARES_SOCKET = socketPath;
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

      RuntimeDirectory = runtimeDir;
      # 0750, not 0755: only group `agent` -- which is the relay and nothing
      # else -- can traverse far enough to reach the socket.
      RuntimeDirectoryMode = "0750";

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
      # home on this box readable, which is exactly the F19 exposure. The
      # paths the service actually needs come back explicitly -- and nothing
      # else does, so a file dropped into /home/agent by hand is invisible to
      # the service until it is named here. `-` means "skip if absent"; these
      # are set up out of band and the unit should not refuse to start over
      # one that has not been created yet.
      ProtectHome = "tmpfs";
      BindPaths = [
        workspace
        "${home}/.claude"
        # Writable: gpg updates random_seed and keeps its agent socket here.
        # Reading it is denied at the CLI layer anyway (`~/.gnupg` is in
        # ANTARES_SECRET_PATHS), so signing works while `cat`ing the keyring
        # does not.
        "-${home}/.gnupg"
        # Same bargain for gh: it needs to write its own config on a version
        # migration, and `~/.config/gh` is on the same deny list, so `gh pr
        # create` works while reading hosts.yml does not.
        "-${home}/.config/gh"
      ];
      BindReadOnlyPaths = [
        appDir
        "-${home}/.gitconfig"
      ];
    };
  };

  # The Pi is behind NAT and the bot host is not, so neither can dial the
  # other; both dial the broker on hk. This is the Pi-side end of that pipe.
  # It carries the agent's own events rather than Telegram API calls, so it has
  # no knowledge of either side's semantics -- see docs/design/04-telegram.md.
  systemd.services.antares-agent-relay = {
    description = "antares-agent: SSE/AMQP relay";
    after = [
      "network-online.target"
      "antares-agent.service"
    ];
    wants = [ "network-online.target" ];
    # Bound rather than merely ordered: without the agent there is no socket to
    # call, and a relay that stays up would keep acknowledging commands it
    # cannot serve.
    bindsTo = [ "antares-agent.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      ANTARES_API_SOCKET = socketPath;
      # Host, port, vhost and credentials all come from the EnvironmentFile
      # below -- they are the retired hermes bridge's, reused wholesale, and
      # guessing any one of them here would only mean a value that looks
      # authoritative while being wrong.
      #
      # The certificate is not the login: verify_peer gates the TLS layer, but
      # AMQP still authenticates with PLAIN on top of it, and the plugin that
      # would map a certificate to a user is not enabled. Only these three
      # paths stay here, because only Nix knows them.
      RMQ_CAFILE = config.age.secrets.agentRelayRabbitCa.path;
      RMQ_CERTFILE = config.age.secrets.agentRelayRabbitCert.path;
      RMQ_KEYFILE = config.age.secrets.agentRelayRabbitKey.path;
      # No proxy here on purpose: AMQP over TLS is not HTTP, so the xray proxy
      # the CLI uses would not apply, and the broker is reachable directly.
    };

    serviceConfig = {
      Type = "exec";
      User = relayUser;
      Group = "users";
      SupplementaryGroups = [ group ];
      ExecStart = "${relayLauncher}/bin/antares-agent-relay-launch";
      Restart = "always";
      RestartSec = "10s";
      EnvironmentFile = config.age.secrets.agentRelayEnv.path;

      # No bwrap here, so none of F12's exemptions are needed -- this is a
      # plain python process that talks to one socket and one broker.
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
        # glibc's getaddrinfo opens a netlink socket to enumerate local
        # addresses for source selection. Without this, resolving the broker's
        # hostname fails in a way that looks like a network problem.
        "AF_NETLINK"
      ];
      MemoryMax = "256M";

      BindReadOnlyPaths = [ appDir ];
    };
  };
}
