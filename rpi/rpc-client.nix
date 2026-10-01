{
  config,
  pkgs,
  lib,
  antares-monitor,
  antares-rpc-client,
  ...
}:
let
  shellenv = import ../common/shellEnv.nix;
in
{
  options.services.antares-rpc-client.enable = lib.mkEnableOption "services.antares-rpc-client";
  config = lib.mkIf (config.services.antares-rpc-client.enable) {

  systemd.services = {
    "rpc-client-antares" = {
      description = "Antares RPC Client Service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        export PATH=$PATH:${shellenv.sysBin}
        ${antares-rpc-client}/bin/antares-rpc-client ${config.age.secrets.rabbitClientCfgAntaresRpi.path}
      '';
      serviceConfig = {
        User = "antares";
        # --- sandbox ---
        # This service runs attacker-supplied shell as `antares` by design, so
        # $HOME must stay writable (git-credential + dispatched commands). We
        # harden only what does NOT break that function.
        NoNewPrivileges = true; # blocks setuid/sudo in dispatched commands; drop if you must send `sudo ...`
        RestrictSUIDSGID = true;
        ProtectSystem = true; # /usr,/boot read-only (NOT "strict": commands need to write)
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        # Deliberately NOT set: ProtectHome (breaks git-credential/home writes),
        # SystemCallFilter (breaks arbitrary tools), MemoryDenyWriteExecute (breaks JITs).
      };
    };
  };

      age.secrets.rabbitClientCfgAntaresRpi = {
        file = ../secrets/rabbit-client-cfg-antares-rpi.age;
        owner = "antares";
        group = "users";
        mode = "440";
      };
  };
}
