{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;
  imports = [
    ./configuration.nix
    ./gitsync.nix
    ./hermes.nix
    ./monitor.nix
    ./multiuser-rpc-client.nix
    ./nix.nix
    ./packages.nix
    ./runner.nix
    ./ssrjson-nixdev-runner.nix
    ./ssrjson-runner.nix
    ./user.nix
    ./xray.nix
  ]
  ++ [
    ../common/agenix.nix
    ../common/env.nix
    ../common/gnupg.nix
    ../common/nix.nix
    ../common/rabbitmq.nix
    ../common/time.nix
    ../common/zsh.nix
    ../common/nix-zshell.nix
  ];
}
