{
  config,
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
        "http_proxy=${envs.envs.http_proxy}"
        "https_proxy=${envs.envs.https_proxy}"
        "XRAY_CONF_DIR=${envs.localFileDef.xrayConfDir}"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
