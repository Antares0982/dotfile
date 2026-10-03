{ ... }:
{
  imports = [
    ./firewall.nix
    ./sysstat.nix
  ];
  services.fail2ban.enable = true;
}
