{ config, lib, ... }:
{
  options.services.antares-rpc-client.enable = lib.mkEnableOption "Antares RPC client";
  config = lib.mkIf config.services.antares-rpc-client.enable {
    age.secrets.rabbitClientCfgAntaresPc = {
      file = ../secrets/rabbit-client-cfg-antares-pc.age;
      owner = "antares";
      group = "users";
      mode = "440";
    };
  };
}
