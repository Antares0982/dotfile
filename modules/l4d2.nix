{
  config,
  lib,
  pkgs,
  l4d2-addons,
  ...
}:
let
  cfg = config.antares.l4d2;
  home = "/home/l4d2";
  game = "${home}/serverfiles/left4dead2";
  addons = l4d2-addons.overrideAttrs (old: {
    postBuild = (old.postBuild or "") + ''
      "$compiler" -i"$includes" -i"$PWD/hooks/sourcemod/scripting/include" \
        multi/hp_tank_show/scripting/hp_tank_show.sp -ocompiled/hp_tank_show.smx
    '';
    postInstallCheck = (old.postInstallCheck or "") + ''
      test -s "$out/addons/sourcemod/plugins/hp_tank_show.smx"
    '';
  });
  runtime =
    (pkgs.steam.override {
      extraLibraries = p: [ p.proxychains-ng ];
    }).run;
  steamcmd = pkgs.steamcmd.override { steam-run = runtime; };
  proxyConfig = pkgs.writeText "l4d2-proxy.conf" ''
    strict_chain
    proxy_dns
    tcp_read_time_out 15000
    tcp_connect_time_out 8000
    localnet 127.0.0.0/255.0.0.0
    localnet ::1/128
    [ProxyList]
    http 127.0.0.1 1081
  '';
  updater = pkgs.writeShellApplication {
    name = "l4d2-download";
    runtimeInputs = [
      steamcmd
      runtime
      pkgs.util-linux
      pkgs.gnugrep
      pkgs.coreutils
    ];
    runtimeEnv.PROXY_CONFIG = toString proxyConfig;
    text = builtins.readFile ../resource/l4d2/update.sh;
  };
  console = pkgs.writeShellScriptBin "l4d2-console" ''
    exec ${pkgs.python3}/bin/python3 ${../resource/l4d2/rcon.py} "$@"
  '';
  serverConfig = pkgs.writeText "server.cfg" ''
    hostname ${builtins.toJSON cfg.serverName}
    sv_lan 0
    sv_password ""
    sv_gametypes "coop"
    mp_gamemode "coop"
    z_difficulty "Impossible"
    sv_allow_lobby_connect_only 0
    sv_force_unreserved 1
    sv_maxplayers 8
    sv_visiblemaxplayers 8
    sv_steam_bypass 0
    sv_steamgroup ""
    exec rcon.cfg
  '';
  multiConfig = pkgs.writeText "l4dmultislots.cfg" ''
    l4d_multislots_min_survivors 4
    l4d_multislots_max_survivors 8
    l4d_multislots_spawn_survivors_roundstart 0
  '';
  gearConfig = pkgs.writeText "l4d_gear_transfer.cfg" ''
    l4d_gear_transfer_method 2
  '';
  prepare = pkgs.writeShellScript "l4d2-prepare" ''
    set -euo pipefail
    test ! -e ${home}/.update-incomplete
    test -x ${home}/serverfiles/srcds_linux
    ${pkgs.rsync}/bin/rsync -r --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r ${addons}/ ${game}/
    rm -f ${game}/addons/metamod_x64.vdf
    install -m644 ${serverConfig} ${game}/cfg/server.cfg
    install -m644 ${multiConfig} ${game}/cfg/sourcemod/l4dmultislots.cfg
    install -m644 ${gearConfig} ${game}/cfg/sourcemod/l4d_gear_transfer.cfg
    install -m600 ${config.age.secrets.l4d2-private.path} ${game}/addons/sourcemod/configs/server-private.cfg
    umask 077
    printf 'rcon_password "%s"\n' "$(cat ${config.age.secrets.l4d2-rcon.path})" > ${game}/cfg/rcon.cfg
  '';
in
{
  options.antares.l4d2.enable = lib.mkEnableOption "L4D2 campaign server" // {
    description = ''
      Enable the L4D2 campaign server.

      `antares.l4d2.enable` controls the dedicated `l4d2` user, services, timer,
      RCON secret, and UDP 27015. Local SSH alias `gz-l4d2` uses `~/.ssh/gz-l4d2`.
      The account has no password or sudo privileges. Manage system services through
      the existing `gz` alias as `antares`.

      The server supports four to eight survivors, accepts passwordless direct
      connections at `<ip>:27015`, and uses `-nomaster` with lobby matching
      disabled. Direct connections remain unrestricted. The cloud firewall must also
      allow inbound UDP 27015; Nix manages only the guest firewall. Game updates run at 05:00
      Asia/Shanghai daily and stop the server while updating. Failed updates leave
      `/home/l4d2/.update-incomplete`; a successful retry clears it. Do not remove
      that marker to start a partially updated installation.

      ```bash
      ssh gz-l4d2
      l4d2-console status
      l4d2-console 'sm plugins list'
      ssh gz 'sudo systemctl start l4d2-update'
      ssh gz 'sudo systemctl restart l4d2'
      ssh gz 'sudo journalctl -u l4d2 -u l4d2-update -n 100'
      ```

      SteamCMD first tries anonymous Linux installation, then Windows/Linux content
      installation for the upstream platform error. Network failures retry through
      the local HTTP proxy on 1081. Download output is available in
      `/home/l4d2/steam-update.log`. Steam authentication is only needed if anonymous
      installation stops working; complete Steam Guard interactively before attempting
      to migrate encrypted authentication state. Never store passwords in Nix values.

      Place manually managed workshop VPKs in
      `/home/l4d2/serverfiles/left4dead2/addons/`. Nix does not download maps or delete
      unmanaged addons. Restart after map changes. Mission Manager and ACS keep their
      generated map lists and caches in the writable SourceMod tree.

      GZ enables `antares.l4d2.fileServer.enable` for authenticated downloads at
      `https://gz.chr.fan:8443/`, with username `l4d2`. Only top-level VPK and JPG
      files are exposed; JPGs have previews. Keep uploaded files readable (0644).
      The cloud firewall must allow TCP 8443. Certificates renew through Cloudflare
      DNS verification without opening 80 or 443. Disabling L4D2 also disables downloads.
      Set or rotate the independent download password on PC, then rebuild GZ:

      ```bash
      nix shell nixpkgs#apacheHttpd nixpkgs#age -c bash scripts/set-l4d2-password.sh
      nix shell nixpkgs#nginx nixpkgs#apacheHttpd -c python3 scripts/test-l4d2-files.py
      ```

      The `l4d2-plugins` flake input owns plugin compilation and pinned third-party
      addons. Update it with `nix flake update l4d2-plugins --flake ./hosts/gz`.
      Plugin binaries and gamedata do not update automatically with Steam.

      Private player aliases and broadcasts live in `secrets/l4d2-private.age`.
      Edit with `agenix -e secrets/l4d2-private.age`, then deploy and restart.
      The service installs the decrypted KeyValues file as `configs/server-private.cfg`
      with mode 0600. Private values never enter plugin builds or the Nix store.

      Run `python3 scripts/test-l4d2.py` and `bash scripts/check-configs.sh gz` after
      changes. Verify `plugin_print`, `meta list`, `sm plugins list`, `sm exts list`,
      and `sm_lmm_list coop` through `l4d2-console` after deployment. Eight real clients
      are required to validate full player capacity; bots alone cannot prove it.
    '';
  };
  options.antares.l4d2.serverName = lib.mkOption {
    type = lib.types.str;
    default = "Antares GZ L4D2";
    description = "Displayed game server name.";
  };
  options.antares.l4d2.authorizedKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMqUj4N9enqwZ8UGUq5DQ4uij6mzIKLYomkpUNZQinXm l4d2@gz"
    ];
    description = "SSH keys for the game account.";
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfreePredicate =
      p:
      builtins.elem (lib.getName p) [
        "steamcmd"
        "steam"
        "steam-unwrapped"
      ];
    users.groups.l4d2 = { };
    users.users.l4d2 = {
      isNormalUser = true;
      group = "l4d2";
      inherit home;
      createHome = true;
      homeMode = "0700";
      hashedPassword = "!";
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };
    age.secrets.l4d2-rcon = {
      file = ../secrets/l4d2-rcon.age;
      owner = "l4d2";
      group = "l4d2";
      mode = "0400";
    };
    age.secrets.l4d2-private = {
      file = ../secrets/l4d2-private.age;
      owner = "l4d2";
      group = "l4d2";
      mode = "0400";
    };
    environment.systemPackages = [ console ];
    networking.firewall.allowedUDPPorts = [ 27015 ];
    systemd.services.l4d2 = {
      description = "L4D2 campaign server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "${home}/serverfiles/srcds_linux";
      environment.HOME = home;
      path = [ pkgs.coreutils ];
      serviceConfig = {
        User = "l4d2";
        Group = "l4d2";
        WorkingDirectory = "${home}/serverfiles";
        ExecStartPre = prepare;
        ExecStart = "${runtime}/bin/steam-run ./srcds_run -game left4dead2 -console -norestart -nomaster -ip 0.0.0.0 -port 27015 +sv_setmax 31 -maxplayers 31 +map c1m1_hotel";
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStopSec = 45;
        UMask = "0077";
      };
    };
    systemd.services.l4d2-update = {
      description = "Install and update L4D2";
      restartIfChanged = false;
      stopIfChanged = false;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.systemd
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "4h";
        UMask = "0077";
      };
      script = ''
        systemctl stop l4d2.service
        runuser -u l4d2 -- env HOME=${home} ${updater}/bin/l4d2-download
        systemctl start --no-block l4d2.service
      '';
    };
    systemd.services.l4d2-install = {
      description = "Initialize L4D2 installation";
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "!${home}/serverfiles/srcds_linux";
      serviceConfig.Type = "oneshot";
      script = "${pkgs.systemd}/bin/systemctl start --no-block l4d2-update.service";
    };
    systemd.timers.l4d2-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:00:00 Asia/Shanghai";
        Persistent = false;
      };
    };
  };
}
