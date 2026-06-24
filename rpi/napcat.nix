{
  config,
  pkgs,
  napcat,
  ...
}:
let
  napcatWrapped = pkgs.writeShellApplication {
    name = "napcat-wrapped";
    runtimeInputs = [ napcat ];
    text = ''
      exec NapCat /home/napcat -q "$QQ_ID"
    '';
  };
in
{
  users.users.napcat = {
    isNormalUser = true;
    home = "/home/napcat";
    description = "napcat service user";
    useDefaultShell = true;
  };

  systemd.services.napcat = {
    description = "NapCat QQ";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "napcat";
      ExecStart = "${napcatWrapped}/bin/napcat-wrapped";
      Restart = "on-failure";
      RestartSec = "10s";
      EnvironmentFile = config.age.secrets.napcatEnv.path;
    };
  };
}
