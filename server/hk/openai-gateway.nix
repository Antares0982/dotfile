{
  config,
  lib,
  pkgs,
  ...
}:
let
  secret = config.age.secrets.openaiPersonalApiKey;
in
{
  options.services.openai-gateway.enable = lib.mkEnableOption "local OpenAI API gateway";

  config = lib.mkIf config.services.openai-gateway.enable {
    assertions = [
      {
        assertion = config.antares.proxy.enable;
        message = "openai-gateway requires the local Mihomo proxy.";
      }
    ];

    users.groups.openai-gateway = { };
    users.users.openai-gateway = {
      isSystemUser = true;
      group = "openai-gateway";
    };
    age.secrets.openaiPersonalApiKey = {
      file = ../../secrets/openai-personal-api-key.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.openai-gateway = {
      description = "Local OpenAI API gateway";
      wantedBy = [ "multi-user.target" ];
      wants = [ "mihomo.service" ];
      after = [ "mihomo.service" ];
      restartTriggers = [ secret.file ];
      environment = {
        HTTPS_PROXY = config.antares.proxy.httpUrl;
        XDG_DATA_HOME = "/tmp";
      };
      serviceConfig = {
        User = "openai-gateway";
        Group = "openai-gateway";
        LoadCredential = [ "openai-api-key:${secret.path}" ];
        ExecStart = "${lib.getExe pkgs.caddy} run --adapter caddyfile --config ${./openai-gateway.Caddyfile}";
        Restart = "on-failure";
        UnsetEnvironment = [
          "NO_PROXY"
          "no_proxy"
        ];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
