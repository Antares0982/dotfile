{ lib, currentDevice, ... }:
let
  domainDNSMatch = {
    "alyr.dev" = "cloudflare";
    "mail.alyr.dev" = "cloudflare";
    "chr.fan" = "cloudflare";
    "en.chr.fan" = "cloudflare";
  };
in
{
  priorDomain = if currentDevice.server.hk or false then "chr.fan" else "alyr.dev";
  validDomains = lib.optionals currentDevice.server.hk [
    "chr.fan"
    "alyr.dev"
    "mail.alyr.dev"
    "en.chr.fan"
  ];
  domainDNSProvider = name: domainDNSMatch.${name};
}
