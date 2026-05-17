{ currentDevice, ... }:
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
    ./user.nix
    ./xrayService.nix
  ]
  ++ [
    (if currentDevice.server.hk then ./hk else ./gz)
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
    jails = {
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
  };
  environment.variables = {
    NIX_DOT_FILES = "/home/antares/Nix";
  };
  programs.zsh = {
    shellAliases = commonEnvs.aliases;
    # interactiveShellInit = ''
    #   WPDIR=$(cat $(ps aux | grep nginx.conf | grep -v grep | awk '{for(i=NF; i>0; i--) if($i != "") {print $i; break}}') | grep share/wordpress | awk '{for(i=NF; i>0; i--) if($i != "") {print $i; break}}' | sed 's/.$//')
    # '';
    shellInit = ''
      export PATH=$PATH:$HOME/scripts:$HOME/scripts/linux
    '';
  };
  networking =
    if currentDevice.server.hk then
      {
        hostName = "hk";
        domain = "chr.fan";
      }
    else
      {
        hostName = "gz";
        domain = "alyr.dev";
      };
  system.stateVersion = "23.11";
}
