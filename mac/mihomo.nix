{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.antares.mihomo;
  tools = (import ../packages { inherit pkgs; }).mihomo-tools;
  template = pkgs.writeText "mihomo-base.json" (
    builtins.toJSON (
      cfg.settings
      // {
        external-ui = "${pkgs.metacubexd}";
      }
    )
  );
  firewall = pkgs.writeText "mihomo.pf" ''
    table <mihomo_clients> const { 127.0.0.0/8, 192.168.0.0/24 }
    block drop in quick inet proto tcp from ! <mihomo_clients> to any port 17900
    block drop in quick inet6 proto tcp from any to any port 17900
  '';
in
{
  imports = [
    ../modules/mihomo-common.nix
    inputs.agenix.darwinModules.default
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.lan;
        message = "Darwin Mihomo proxy ports are local-only; use dashboardLan for management.";
      }
    ];
    environment.systemPackages = [
      tools
      tools.clashtui
    ];
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.secrets.mihomoSubscription = {
      file = ../secrets/xraysub.age;
      owner = "antares";
      group = "staff";
      mode = "0400";
    };
    launchd.daemons.mihomo = {
      command = lib.escapeShellArgs [
        "${pkgs.python3}/bin/python3"
        "${../resource/mihomo-darwin.py}"
        template
        config.age.secrets.mihomoSubscription.path
        "${../resource/mihomo-prepare.py}"
        "${pkgs.mihomo}/bin/mihomo"
        "${tools}/bin/mihomoctl"
        (if cfg.dashboardLan then firewall else "")
      ];
      environment = {
        SAFE_PATHS = "${pkgs.metacubexd}";
        # Restart when encrypted subscription changes.
        MIHOMO_SUBSCRIPTION_SOURCE = toString config.age.secrets.mihomoSubscription.file;
      };
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ExitTimeOut = 30;
        Umask = 63;
        StandardOutPath = "/var/log/mihomo.log";
        StandardErrorPath = "/var/log/mihomo.log";
      };
    };
  };
}
