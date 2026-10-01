{ config, lib, ... }:
{
  options.antares.acme.enable = lib.mkEnableOption "Cloudflare ACME certificates";
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.antares.acme.enable || config.security.acme.certs == { };
          message = "Configured certificates require antares.acme.enable.";
        }
      ];
    }
    (lib.mkIf config.antares.acme.enable {
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "antares0982@gmail.com";
          dnsResolver = "1.1.1.1:53";
          dnsProvider = "cloudflare";
          environmentFile = config.age.secrets.cloudflareEnv.path;
          webroot = null;
        };
      };
      users.users.acme.extraGroups = lib.mkIf (config.security.acme.certs != { }) [ "nginx" ];
    })
    (lib.mkIf (config.antares.acme.enable && config.security.acme.certs != { }) {
      users.groups.nginx = { };
      age.secrets.cloudflareEnv = {
        file = ../../secrets/cloudflare-env.age;
        owner = "acme";
        group = "nginx";
      };
    })
  ];
}
