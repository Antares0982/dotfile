{ pkgs, lib, ... }:
let
  commonEnv = import ../../../common/shellEnv.nix;
  localFileDef = import ../../../common/localFileDef.nix {
    username = "antares";
  };
  nix-zshell = (import ../../../packages { inherit pkgs; }).nix-zshell;
in
rec {
  inherit localFileDef;
  inherit (localFileDef) username userhome;
  inherit (commonEnv) sysBin;
  usernameCap = "Antares";
  envs = rec {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
    HTTP_PROXY = http_proxy;
    HTTPS_PROXY = https_proxy;
    GITHUB_DIR = localFileDef.githubDir;
    SCRIPT_DIR = localFileDef.scriptDir;
    XRAY_CONF_DIR = localFileDef.xrayConfDir;
    XRAY_CONFIG_PATH = localFileDef.xrayConfPath;
    XRAY_TEMPLATE = localFileDef.xrayConfTemplatePath;
    GPG_TTY = "$TTY";
    NIX_BUILD_SHELL = "${nix-zshell}/bin/nix-zshell";
    NIX_DOT_FILES = "${localFileDef.githubDir}/Nix";
    EDITOR = "nvim";
  };
}
