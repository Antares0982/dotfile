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
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
