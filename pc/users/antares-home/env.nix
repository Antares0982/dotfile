{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
in
{
  home.sessionVariables =
    builtins.removeAttrs envs.envs [
      "http_proxy"
      "https_proxy"
      "HTTP_PROXY"
      "HTTPS_PROXY"
      "XRAY_CONF_DIR"
      "XRAY_CONFIG_PATH"
      "XRAY_TEMPLATE"
    ]
    // lib.optionalAttrs osConfig.antares.proxy.enable {
      http_proxy = osConfig.antares.proxy.httpUrl;
      https_proxy = osConfig.antares.proxy.httpUrl;
      HTTP_PROXY = osConfig.antares.proxy.httpUrl;
      HTTPS_PROXY = osConfig.antares.proxy.httpUrl;
    }
    // lib.optionalAttrs osConfig.antares.xray.enable {
      inherit (envs.envs) XRAY_CONF_DIR XRAY_CONFIG_PATH XRAY_TEMPLATE;
    };
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
