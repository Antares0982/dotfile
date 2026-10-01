{
  config,
  osConfig,
  pkgs,
  lib,
  pull-all,
  xray-sub,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
  nix = "${pkgs.nix}/bin/nix";
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
        ${envs.sysBin}/bash "${envs.envs.SCRIPT_DIR}/linux/_nixautostart"
      '';
      Environment = [
        "PULL_ALL=${pull-all}/bin/pull-all"
        "XRAY_SUB=${xray-sub}/bin/xray_sub"
        "HOME=${envs.userhome}"
        "SCRIPT_DIR=${envs.envs.SCRIPT_DIR}"
        "XRAY_TEMPLATE=${envs.envs.XRAY_TEMPLATE}"
        "GITHUB_DIR=${envs.envs.GITHUB_DIR}"
        "GIT_DIRS=${envs.envs.GITHUB_DIR}"
        "XRAY_CONF_DIR=${envs.localFileDef.xrayConfDir}"
      ] ++ lib.optionals osConfig.antares.proxy.enable [ "http_proxy=${osConfig.antares.proxy.httpUrl}" "https_proxy=${osConfig.antares.proxy.httpUrl}" ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  };
}
