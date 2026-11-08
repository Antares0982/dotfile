{
  osConfig,
  pkgs,
  lib,
  pull-all,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
in
{
  config = lib.mkIf (osConfig.antares.autostart.enable) {

    systemd.user.services.autostart = {
      Unit = {
        Description = "${envs.usernameCap} Auto Start Service";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        WorkingDirectory = "${envs.envs.SCRIPT_DIR}";
        ExecStart = ''
          ${envs.sysBin}/bash ${../../../resource/nix-autostart.sh}
        '';
        Environment = [
          "PULL_ALL=${pull-all}/bin/pull-all"
          "HOME=${envs.userhome}"
          "SCRIPT_DIR=${envs.envs.SCRIPT_DIR}"
          "GITHUB_DIR=${envs.envs.GITHUB_DIR}"
          "GIT_DIRS=${envs.envs.GITHUB_DIR}"
        ]
        ++ lib.optionals osConfig.antares.proxy.enable [
          "http_proxy=${osConfig.antares.proxy.httpUrl}"
          "https_proxy=${osConfig.antares.proxy.httpUrl}"
        ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  };
}
