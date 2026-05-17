{
  config,
  lib,
  pkgs,
  currentDevice,
  ...
}:
let
  hkServer = currentDevice.server.hk or false;
in
{
  services.rabbitmq = lib.mkMerge [
    {
      enable = true;
      listenAddress = if hkServer then "0.0.0.0" else "127.0.0.1";
      managementPlugin.enable = true;
    }
    (lib.mkIf hkServer {
      configItems = {
        "listeners.ssl.default" = "5671";
        "ssl_options.cacertfile" = "/var/rabbitmq_crt/ca.crt";
        "ssl_options.certfile" = "/var/rabbitmq_crt/server.crt";
        "ssl_options.keyfile" = "/var/rabbitmq_crt/server.key";
        "ssl_options.verify" = "verify_peer";
        "ssl_options.fail_if_no_peer_cert" = "true";
      };
    })
  ];
  networking.firewall.allowedTCPPorts = lib.optionals hkServer [ 5671 ];
}
