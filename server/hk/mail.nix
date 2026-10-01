{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.nixos-mailserver.nixosModules.default ];
  config = lib.mkIf (config.mailserver.enable) {

    security.acme.certs."chr.fan" = { };

    mailserver = {
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

    age.secrets.mailPasswordAntares = {
      file = ../../secrets/mail-password-antares.age;
    };
    age.secrets.mailPasswordAlyr = {
      file = ../../secrets/mail-password-alyr.age;
    };
    services.fail2ban.jails = {
      postfix-sasl = ''
        enabled = true
        filter = postfix[mode=auth]
        logpath = /var/log/mail.log
        maxretry = 3
        bantime = 3600
        findtime = 600
      '';
      dovecot = ''
        enabled = true
        filter = dovecot
        logpath = /var/log/mail.log
        maxretry = 3
        bantime = 3600
        findtime = 600
      '';
    };
    security.acme.certs."mail.alyr.dev" = { };
  };
}
