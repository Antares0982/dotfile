{ config, lib, ... }:
{
  options.services.antares-rpc-client.enable = lib.mkEnableOption "Antares RPC client";
  config = lib.mkIf config.services.antares-rpc-client.enable {
    age.secrets.rabbitClientCfgAlice = {
      file = ../../secrets/rabbit-client-cfg-alice.age;
      owner = "alice";
      group = "users";
      mode = "440";
    };
  };
}
