{
  config,
  pkgs,
  lib,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
in
{
  home.sessionVariables = envs.envs;
  programs.zsh = {
    enable = true;
    shellAliases = envs.aliases;
    initContent = ''
      source ${envs.localFileDef.p10kConfPath}
      eval "$(direnv hook zsh)"
      export PATH=$PATH:${envs.envs.SCRIPT_DIR}:${envs.envs.SCRIPT_DIR}/linux
    ''
    + envs.shellInitExtra;
  };
}
