{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.antares.mihomo;
  proxy = config.antares.proxy;
  tools = (import ../packages { inherit pkgs; }).mihomo-tools;
  template = pkgs.writeText "mihomo-base.json" (
    builtins.toJSON (
      cfg.settings
      // lib.optionalAttrs proxy.lan {
        external-ui = "${pkgs.metacubexd}";
      }
    )
  );
in
{
  imports = [
    ../modules/mihomo-common.nix
    inputs.agenix.darwinModules.default
  ];

  config = lib.mkMerge [
    {
      system.activationScripts.postActivation.text = lib.mkAfter ''
        ${pkgs.python3}/bin/python3 ${../resource/mihomo-darwin.py} chrome ${
          if proxy.exportEnvironment then "on" else "off"
        }
        ${lib.optionalString (!(proxy.enable && (proxy.insideGFW || proxy.lan))) ''
          ${pkgs.python3}/bin/python3 ${../resource/mihomo-darwin.py} cleanup
        ''}
      '';
    }
    (lib.mkIf proxy.enable {
      users.knownGroups = [ "_mihomo" ];
      users.groups._mihomo.gid = 493;
      users.knownUsers = [ "_mihomo" ];
      users.users._mihomo = {
        uid = 397;
        gid = config.users.groups._mihomo.gid;
        home = "/var/empty";
        shell = "/usr/bin/false";
      };
      environment.systemPackages = [ tools ];
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
        ];
        environment = {
          MIHOMO_CLIENT_ADDRESS = proxy.clientAddress;
          SKIP_SYSTEM_IPV6_CHECK = "1";
          # Restart when encrypted subscription changes.
          MIHOMO_SUBSCRIPTION_SOURCE = toString config.age.secrets.mihomoSubscription.file;
        }
        // lib.optionalAttrs proxy.lan { SAFE_PATHS = "${pkgs.metacubexd}"; };
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
    })
  ];
}
