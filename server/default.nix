{ ... }:
let
  commonEnvs = import ../common/shellEnv.nix;
in
{
  imports = [
    ./hardware
  ]
  ++ [
    ./firewall.nix
    ./mysql.nix
    ./packages.nix
    ./sysstat.nix
    ./user.nix
    ./xrayService.nix
  ]
  ++ [
    ../common/env.nix
    ../common/nix.nix
    ../common/rabbitmq.nix
    ../common/ssh.nix
    ../common/time.nix
    ../common/zsh.nix
  ];
  services.fail2ban = {
    enable = true;

  };
  environment.variables = {
    NIX_DOT_FILES = "/home/antares/Nix";
  };
  programs.zsh = {
    shellAliases = commonEnvs.aliases;
    shellInit = ''
      export PATH=$PATH:$HOME/scripts:$HOME/scripts/linux
    '';
  };
  system.stateVersion = "23.11";
}
