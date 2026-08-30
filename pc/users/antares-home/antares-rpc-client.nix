{
  config,
  pkgs,
  lib,
  antares-rpc-client,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
  nix = "${pkgs.nix}/bin/nix";
in
{
  systemd.user.services.rpc-client = {
    Unit = {
      Description = "${envs.usernameCap} RPC Client Service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = "${envs.userhome}";
      ExecStart = ''
        ${antares-rpc-client}/bin/antares-rpc-client /run/agenix/rabbitClientCfgAntaresPc
      '';
      Environment = [
        "HOME=${envs.userhome}"
        "PATH=${envs.sysBin}"
      ];
      # --- sandbox ---
      # This service runs attacker-supplied shell as your user by design, so
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

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
