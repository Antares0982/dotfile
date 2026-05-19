{
  config,
  pkgs,
  lib,
  hermes-agent-pkg,
  hermes-antares-bridge-pkg,
  ...
}:
let
  my-plugin = pkgs.runCommand "hermes-antares-bridge-plugin"
    { }
    ''
      mkdir -p $out
      cp ${hermes-antares-bridge-pkg.src}/plugin.yaml $out/
      cp ${hermes-antares-bridge-pkg.src}/__init__.py $out/
      cp ${hermes-antares-bridge-pkg.src}/adapter.py $out/
      cp ${hermes-antares-bridge-pkg.src}/protocol.py $out/
    '';
in
{
  services.hermes-agent = {
    enable = true;
    package = hermes-agent-pkg;
    extraPlugins = [ my-plugin ];
    extraPythonPackages = with pkgs.python312Packages; [ aio-pika ];
    settings.plugins.enabled = [ "hermes-antares-bridge" ];
  };
}
