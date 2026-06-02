{
  config,
  pkgs,
  nixos-mailserver,
  ...
}:
{
  imports = [
    nixos-mailserver.nixosModules.default
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
