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
