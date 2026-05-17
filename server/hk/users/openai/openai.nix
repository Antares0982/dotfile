{
  config,
  pkgs,
  lib,
  ...
}:
let
  userenvs = import ./_userenv.nix;
in
{
  systemd.user.services.openai = {
    Unit = {
      Description = "OpenAI Session Management";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      WorkingDirectory = "${userenvs.home}/OpenAISession";
      ExecStart = ''/bin/sh -c "PATH=$PATH:${userenvs.sysBin} ${pkgs.nix}/bin/nix develop -c \"./run_openai.sh\""'';
      Environment = [
      ];
      Restart = "on-failure";
      RestartSec = "20s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
