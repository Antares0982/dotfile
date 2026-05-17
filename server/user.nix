{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCommonSettings = import ../common/users.nix {
    inherit (config.age) secrets;
  };
in
{
  users = {
    mutableUsers = false;
    users.antares = {
      isNormalUser = true;
      home = "/home/antares";
      description = "Antares0982";
      extraGroups = [
        "wheel"
      ];
      uid = 1000;
      useDefaultShell = true;
      hashedPasswordFile = userCommonSettings.serverHashedPasswordFile;
      openssh.authorizedKeys.keys = [ userCommonSettings.superUserAuthorizedKey ];
      linger = true;
    };
    users.git = {
      isNormalUser = true;
      home = "/home/git";
      description = "git server";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCxnUFPD4ohzXi8j2jyDo5354xTXwjB7ujIi3hF39kiORnB8pJbMj0Z0eF/Qn/XGVGm/8g0sHGt2VQjhUSV7dyftHmUvZESbtczGcEzSRSOdx61r05TkCtZGgdCZZau2+qom6LL5yk58iN2Qxclln5ZVrNXaZyDThGbulLBd/s8eWgp9llO8crLEe0VbCFujCpiqkIV8cinNLY4AlcR9TIFxDMHXu/RGK/iI2xnfnwXGDkjSILscrxgLHiMakgCfq7ihLPdXbHxebDsDkYZOq1h0tEXNZXAAjZtH5C26mAO451AK8TNyA7lPGl8/OatEbkhBIrQEtRYnRXWbNKsajVbshK8w1JO5o/k/aBZsUHcyI4jMP1lmSsgAEWEp5pPobNDxTUFAsurOOfgNBSoUj98HoEqBISYBAn0xPfwh2YdT5/03P7rI5LyW3zzV99/THqX6PQKlhr0X0f/Fkx3oswv1C2kpbkeTuxuuxCRAEtnWaYn0lmh0G8LZWOeGP2HLUqu5hQySjHgdWEEUKBxoQhZ+lBUFJX4OnxhCaERG/fYCMlUUU5au4nKUNqpXQcmdUe0PLsq8BBs0JEl9LPkH31AAXORbQF6uvWDCVqm4IqHGbhCkxAjqrmZ0zJlejxn0J60kz1Gj50gzPj7FuzxMG83MSz7FLW44HD8rZYHSABQuQ== antares@nixos"
      ];
      inherit (userCommonSettings) hashedPasswordFile;
    };
    users.visitorbadge = {
      isSystemUser = true;
      description = "Visitor Badge service user";
      shell = "/usr/sbin/nologin";
      group = "visitorbadge";
    };
    groups.visitorbadge = { };
  };
  users.defaultUserShell = pkgs.zsh;
  imports = [ ../common/sudo.nix ];
}
