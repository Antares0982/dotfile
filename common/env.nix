{
  lib,
  currentDevice,
  ...
}:
{
  environment.variables = lib.attrsets.optionalAttrs currentDevice.useProxy {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
  };
}
