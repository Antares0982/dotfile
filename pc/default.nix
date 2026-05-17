{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./chrome.nix
    ./configuration.nix
    ./display.nix
    ./docker.nix
    ./fcitx5.nix
    ./fonts.nix
    ./haruna.nix

    ./network.nix
    ./nix.nix
    ./nvidia.nix
    ./packages.nix
    ./qq.nix
    ./rust.nix
    ./samba.nix
    ./ssh.nix
    ./steam.nix
    ./typora.nix
    ./user.nix
    ./vscode.nix
    ./ydotool.nix
  ]
  ++ [
    ../common/agenix.nix
    ../common/git-sign.nix
    ../common/gnupg.nix
    ../common/nix.nix
    ../common/nix-zshell.nix
    ../common/rabbitmq.nix
    ../common/time.nix
    ../common/zsh.nix
  ];
}
