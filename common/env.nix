{
  lib,
  config,
  currentDevice,
  ...
}:
{
  environment.variables = lib.mkMerge [
    {
      UV_PYTHON_DOWNLOADS = "never";
    }
    (lib.mkIf (config.antares.proxy.enable or currentDevice.useProxy) {
      http_proxy = config.antares.proxy.httpUrl or "http://127.0.0.1:1081";
      https_proxy = config.antares.proxy.httpUrl or "http://127.0.0.1:1081";
    })
  ];
}
