# Left 4 Dead 2 dedicated server (LAN mode, 8-player campaign).
#
# Design:
#   - Game files (app 222860) are mutable and self-updating; steamcmd installs
#     them into a persistent StateDirectory. They never live in the Nix store.
#   - The srcds binary is FHS-dependent, so it runs under `steam-run`.
#   - Base mods (MetaMod:Source, SourceMod, l4dtoolz) are pinned in ./mods.nix
#     and copied in idempotently, refreshed only when their versions change.
#   - The 8-survivor campaign plugin (l4d2multislots) is fetched separately by
#     resource/l4d2-fetch-plugins.sh into the persistent SourceMod tree; it lives
#     in the StateDirectory and is never touched by Nix. (Left4DHooks is not
#     needed for this setup.)
#   - LAN mode (sv_lan 1): the server never registers with the Steam master
#     server, so it is unsearchable. Join only via `connect <ip/domain>`.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = "/var/lib/l4d2";
  serverDir = "${home}/server";
  gameDir = "${serverDir}/left4dead2";
  appId = "222860";
  port = 27015;

  mods = import ./mods.nix { inherit pkgs; };

  # Fully Nix-managed; overwritten on every start (source of truth).
  serverCfg = pkgs.writeText "l4d2-server.cfg" ''
    hostname "L4D2 Private Server"

    // --- LAN mode: not listed anywhere, join by connect <ip/domain> only ---
    sv_lan 1
    sv_allow_lobby_connect_only 0
    sv_force_unreserved 1

    // --- 8 human players (sv_maxplayers is provided by l4dtoolz) ---
    sv_maxplayers 8
    mp_gamemode coop

    // 8 survivor slots in campaign (provided by the l4d2multislots plugin)
    l4d2_multislots_max_survivors 8

    exec rcon.cfg
  '';

  updateScript = pkgs.writeShellScript "l4d2-update" ''
    set -eu
    mkdir -p ${serverDir}
    ${pkgs.steam-run}/bin/steam-run ${pkgs.steamcmd}/bin/steamcmd \
      +force_install_dir ${serverDir} \
      +login anonymous \
      +app_update ${appId} \
      +quit
  '';

  installModsScript = pkgs.writeShellScript "l4d2-install-mods" ''
    set -eu
    mkdir -p ${gameDir}/cfg ${gameDir}/addons

    # Refresh the managed base only when the pinned versions change, so we never
    # clobber hand-placed plugins or edited SourceMod configs on every restart.
    stamp=${home}/.nix-mods-rev
    want=${builtins.baseNameOf mods}
    if [ "$(cat "$stamp" 2>/dev/null || true)" != "$want" ]; then
      echo "l4d2: installing managed mods ($want)"
      cp -rf --no-preserve=mode,ownership ${mods}/addons/. ${gameDir}/addons/
      cp -rf --no-preserve=mode,ownership ${mods}/cfg/. ${gameDir}/cfg/
      echo "$want" > "$stamp"
    fi

    cp -f ${serverCfg} ${gameDir}/cfg/server.cfg
    chmod 644 ${gameDir}/cfg/server.cfg

    # rcon password from the agenix secret (single-line plaintext).
    umask 077
    printf 'rcon_password "%s"\n' "$(cat ${config.age.secrets.l4d2Rcon.path})" \
      > ${gameDir}/cfg/rcon.cfg
  '';
in
{
  users.users.l4d2 = {
    isSystemUser = true;
    group = "l4d2";
    home = home;
    description = "L4D2 dedicated server";
  };
  users.groups.l4d2 = { };

  networking.firewall = {
    allowedUDPPorts = [
      27015 # game
      27005 # client
    ];
    allowedTCPPorts = [
      27015 # rcon
    ];
  };

  systemd.services.l4d2 = {
    description = "Left 4 Dead 2 dedicated server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "l4d2";
      Group = "l4d2";
      StateDirectory = "l4d2";
      WorkingDirectory = home;
      Environment = [ "HOME=${home}" ];
      ExecStartPre = [
        updateScript
        installModsScript
      ];
      ExecStart = "${pkgs.steam-run}/bin/steam-run ${serverDir}/srcds_run -game left4dead2 -console -port ${toString port} +exec server.cfg +map c1m1_hotel";
      Restart = "on-failure";
      RestartSec = 10;
      # First run downloads the full ~13 GB game; allow a long start.
      TimeoutStartSec = 7200;
    };
  };
}
