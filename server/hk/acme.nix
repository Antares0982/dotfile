{
  config,
  lib,
  pkgs,
  currentDevice,
  ...
}:
let
  domainSettings = pkgs.callPackage ../_domains.nix { inherit currentDevice; };
  domainDNSProvider = domainSettings.domainDNSProvider;
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "antares0982@gmail.com";
    # certs = lib.attrsets.mapAttrs'
    #   (name: value: value)
    #   (lib.genAttrs domainSettings.validDomains (x: {
    #     dnsProvider = domainSettings.domainDNSProvider x;
    #   }));
    # certs = lib.attrsets.mapAttrs'
    #   (name: value: { name = "${name}"; value = value; })
    #   (lib.genAttrs domainSettings.validDomains (domain: {
    #     dnsProvider = domainSettings.domainDNSProvider domain;
    #     environmentFile = "/var/cloudflare-env";
    #   }));
    certs = lib.genAttrs domainSettings.validDomains (domain: {
      dnsProvider = domainDNSProvider domain;
      environmentFile = config.age.secrets.cloudflareEnv.path;
      webroot = null;
    });
    # certs."alyr.dev" = {
    #   dnsProvider = "cloudflare";
    #   environmentFile = "/var/cloudflare-env";
    # };
    # certs."mail.alyr.dev" = {
    #   dnsProvider = "cloudflare";
    #   environmentFile = "/var/cloudflare-env";
    # };
    # Supplying password files like this will make your credentials world-readable
    # in the Nix store. This is for demonstration purpose only, do not use this in production.
    #   environmentFile = "${pkgs.writeText "inwx-creds" ''
    #   INWX_USERNAME=xxxxxxxxxx
    #   INWX_PASSWORD=yyyyyyyyyy
    # ''}";
    # };
  };
}
