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
  mkRunnerUser = username: {
    isNormalUser = true;
    home = "/home/${username}";
    description = "github action runner";
    useDefaultShell = true;
    # openssh.authorizedKeys.keys = [
    #   userCommonSettings.commonUserAuthorizedKey
    # ];
    linger = true;
  };
in
{
  programs.zsh.shellInit = ''
    export PATH=$PATH:$HOME/scripts:$HOME/scripts/linux
  '';
  environment.variables = {
    NIX_DOT_FILES = "/home/antares/Nix";
  };
  users = {
    # mutableUsers = false;
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
    users.actionrunner = (mkRunnerUser "actionrunner") // {
      openssh.authorizedKeys.keys = [
        userCommonSettings.commonUserAuthorizedKey
      ];
    };
    users.ssrjsonrunner = (mkRunnerUser "ssrjsonrunner") // {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
      ];
    };
    users.ssrjsonnixdev = (mkRunnerUser "ssrjsonnixdev") // {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
      ];
    };
    users.hermes = {
      isNormalUser = true;
      home = "/home/hermes";
      useDefaultShell = true;
    };

  };
  users.defaultUserShell = pkgs.zsh;
  imports = [ ../common/sudo.nix ];
}
