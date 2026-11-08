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
    ]
    // lib.optionalAttrs osConfig.antares.proxy.enable {
      http_proxy = osConfig.antares.proxy.httpUrl;
      https_proxy = osConfig.antares.proxy.httpUrl;
      HTTP_PROXY = osConfig.antares.proxy.httpUrl;
      HTTPS_PROXY = osConfig.antares.proxy.httpUrl;
    };
}
