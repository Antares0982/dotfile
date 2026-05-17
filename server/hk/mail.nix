{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchTarball {
      # repo: https://gitlab.com/simple-nixos-mailserver/nixos-mailserver
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/e33fbde199eaad513ef5d0746db19d5878150232/nixos-mailserver-e33fbde199eaad513ef5d0746db19d5878150232.tar.gz";
      sha256 = "sha256:0x73hf947cky34104cfqdaqpxykvcqhykvvg1jz6wrpfakvx4ghn";
    })
  ];

  mailserver = {
    enable = true;
    enablePop3 = true;
    enableSubmission = true;
    fqdn = "mail.alyr.dev";
    domains = [ "alyr.dev" ];

    x509 = {
      certificateFile = "/var/lib/acme/chr.fan/fullchain.pem";
      privateKeyFile = "/var/lib/acme/chr.fan/key.pem";
    };

    # Plaintext passwords are stored in agenix-encrypted files.
    # The dovecot activation script hashes them at runtime via doveadm pw.
    accounts = {
      "antares@alyr.dev" = {
        passwordFile = config.age.secrets.mailPasswordAntares.path;
        # aliases = [ "postmaster@example.com" ];
      };
      "alyr@alyr.dev" = {
        passwordFile = config.age.secrets.mailPasswordAlyr.path;
      };
    };

    stateVersion = 3;
  };
}
