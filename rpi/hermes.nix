{
  config,
  pkgs,
  lib,
  hermes-agent-pkg,
  hermes-antares-bridge-pkg,
  ...
}:
let
  my-plugin = pkgs.runCommand "hermes-antares-bridge-plugin" { } ''
    mkdir -p $out
    cp ${hermes-antares-bridge-pkg.src}/plugin.yaml $out/
    cp ${hermes-antares-bridge-pkg.src}/__init__.py $out/
    cp ${hermes-antares-bridge-pkg.src}/adapter.py $out/
    cp ${hermes-antares-bridge-pkg.src}/protocol.py $out/
  '';

  pythonPackages = pkgs.python312Packages;

  aio-pika-no-yarl = pythonPackages.buildPythonPackage rec {
    pname = "aio-pika";
    version = "9.6.2";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "mosquito";
      repo = "aio-pika";
      tag = version;
      hash = "sha256-N5MjFIolMRTTn4aV1NskBwonB/8FSuEZETumUrAa02Y=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build>=0.9.26,<0.10.0" uv_build
    '';

    build-system = [ pythonPackages.uv-build ];

    dependencies = [

    ];
    pythonRuntimeDepsCheckHook = ":";
    pythonImportsCheckPhase = ":";

    doCheck = false;

    pythonImportsCheck = [ "aio_pika" ];

  };
in
{
  services.hermes-agent = {
    enable = true;
    package = hermes-agent-pkg;
    extraPlugins = [ my-plugin ];
    extraPythonPackages = [
      aio-pika-no-yarl
    ];

    settings = {
      plugins.enabled = [ "hermes-antares-bridge" ];
      terminal.cwd = "/home/hermes";
      platforms.antares = {
        enabled = true;
        extra = {
          rabbitmq_host = "chr.fan";
          rabbitmq_port = 5671;
          rabbitmq_user = "hermes";
          rabbitmq_vhost = "remotecall";
          rabbitmq_cafile = "/run/agenix/hermesRabbitCa";
          rabbitmq_certfile = "/run/agenix/hermesRabbitCert";
          rabbitmq_keyfile = "/run/agenix/hermesRabbitKey";
        };
      };
      model = {
        default = "deepseek-v4-pro";
        provider = "deepseek";
      };
    };

    stateDir = "/home/hermes/.hermes";

    environmentFiles = [
      "/run/agenix/hermesEnv"
    ];
  };
}
