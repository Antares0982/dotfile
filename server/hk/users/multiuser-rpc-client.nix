{
  userenvs,
}:

{
  config,
  antares-rpc-client,
  ...
}:
{
  systemd.user.services.rpc-client = {
    Unit = {
      Description = "Antares RPC Client Service";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = "${userenvs.home}";
      ExecStart = ''
        ${antares-rpc-client}/bin/antares-rpc-client ${userenvs.rabbitClientCfgPath}
      '';
      Environment = [
        "PATH=${userenvs.sysBin}"
      ];
      Restart = "on-failure";
      RestartSec = "20s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
