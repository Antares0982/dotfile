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
    # "rpc-client-actionrunner" = {
    #   description = "Antares RPC Client Service";
    #   after = [ "network-online.target" ];
    #   wants = [ "network-online.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   script = ''
    #     export PATH=$PATH:${shellenv.sysBin}
    #     ${antares-rpc-client}/bin/antares-rpc-client ${config.age.secrets.rabbitClientCfgActionrunner.path}
    #   '';
    #   serviceConfig = {
    #     User = "actionrunner";
    #   };
    # };
  };
}
