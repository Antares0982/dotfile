{ config, lib, ... }:
let
  cfg = config.antares.l4d2;
  enabled = cfg.enable && cfg.fileServer.enable;
  game = "/home/l4d2/serverfiles/left4dead2";
in
{
  imports = [ ./acme.nix ];
  options.antares.l4d2.fileServer.enable = lib.mkEnableOption "L4D2 addon downloads and uploads";

  options.antares.l4d2.fileServer.domain = lib.mkOption {
    type = lib.types.str;
    default = "gz.chr.fan";
    description = "Addon file server domain.";
  };

  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = config.services.nginx.enable;
        message = "L4D2 files require nginx.";
      }
    ];
    antares.acme.enable = true;
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      virtualHosts.${cfg.fileServer.domain} = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 8443;
            ssl = true;
          }
          {
            addr = "[::]";
            port = 8443;
            ssl = true;
          }
        ];
        onlySSL = true;
        enableACME = true;
        acmeRoot = null;
        root = "/srv/l4d2-addons";
        basicAuthFile = config.age.secrets.l4d2-files-htpasswd.path;
        extraConfig =
          builtins.replaceStrings
            [ "@stylesheet@" "@uploads@" ]
            [ "${../resource/l4d2/files.xsl}" "/srv/l4d2-addons/.uploads" ]
            (builtins.readFile ../resource/l4d2/files.conf);
      };
    };
    age.secrets.l4d2-files-htpasswd = {
      file = ../secrets/l4d2-files-htpasswd.age;
      owner = "nginx";
      mode = "0400";
    };
    networking.firewall.allowedTCPPorts = [ 8443 ];
    systemd.tmpfiles.rules = [
      "d /home/l4d2/serverfiles 0700 l4d2 l4d2 - -"
      "d ${game} 0700 l4d2 l4d2 - -"
      "d ${game}/addons 0700 l4d2 l4d2 - -"
      "a+ ${game}/addons - - - - u:nginx:rwx,m::rwx"
      "d ${game}/addons/.uploads 0700 nginx nginx - -"
    ];
    systemd.services.nginx.serviceConfig = {
      BindPaths = [ "${game}/addons:/srv/l4d2-addons" ];
      ReadWritePaths = [ "/srv/l4d2-addons" ];
    };
  };
}
