{ config, pkgs, ... }:
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
    ../../modules/acme.nix
    ./blog.nix
    ./site-metrics.nix
    ./rpc-client.nix
    ./monitor.nix
    ./mail.nix
    ./matrix-appservice.nix
    ./telegram-bot-api.nix
    ./agent-files.nix
  ];
  system.stateVersion = "23.11";
}
