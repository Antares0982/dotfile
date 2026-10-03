{ config, pkgs, ... }:
let
  commonEnvs = import ../../common/shellEnv.nix;
in
{
  imports = [
    ./hardware
    ./mysql.nix
    ./packages.nix
    ./user.nix
    ./xrayService.nix
    ../../common/env.nix
    ../../common/nix.nix
    ../../common/rabbitmq.nix
    ../../common/ssh.nix
    ../../common/time.nix
    ../../common/zsh.nix
    ./users
  ]
  ++ [
    ./messaging.nix
    ./alice.nix
    ./rabbitmq.nix
    ./web.nix
    ./acme.nix
    ./blog.nix
    ./site-metrics.nix
    ./rpc-client.nix
    ./monitor.nix
    ./mail.nix
    ./matrix-appservice.nix
    ./telegram-bot-api.nix
    ./agent-files.nix
  ];
  environment.variables.NIX_DOT_FILES = "/home/antares/Nix";
  programs.zsh = {
    shellAliases = commonEnvs.aliases;
    shellInit = ''
      export PATH=$PATH:$HOME/scripts:$HOME/scripts/linux
    '';
  };
  system.stateVersion = "23.11";
}
