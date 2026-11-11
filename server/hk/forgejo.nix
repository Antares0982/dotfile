{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.forgejo;
  domain = "git.chr.fan";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.nginx.enable;
        message = "Forgejo requires services.nginx.enable.";
      }
      {
        assertion = config.services.openssh.enable;
        message = "Forgejo requires services.openssh.enable.";
      }
    ];

    services.forgejo = {
      user = "git";
      group = "git";
      settings = {
        server = {
          DOMAIN = domain;
          ROOT_URL = "https://${domain}/";
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = 3000;
          LANDING_PAGE = "login";
          SSH_DOMAIN = domain;
          SSH_PORT = 22;
          START_SSH_SERVER = false;
        };
        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };
        session.COOKIE_SECURE = true;
      };
    };

    users.users.git = {
      isSystemUser = true;
      description = "Forgejo";
      group = cfg.group;
      home = cfg.stateDir;
      createHome = true;
      homeMode = "0750";
      shell = pkgs.bashInteractive;
    };
    users.groups.git = { };
    environment.systemPackages = [ cfg.package ];

    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      enableACME = true;
      acmeRoot = null;
      extraConfig = ''
        client_max_body_size 512M;
        merge_slashes off;
      '';
      locations."/" = {
        proxyPass = "http://${cfg.settings.server.HTTP_ADDR}:${toString cfg.settings.server.HTTP_PORT}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
  };
}
