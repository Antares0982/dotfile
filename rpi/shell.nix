{ config, pkgs, ... }:
{
  environment.etc."zsh/p10k.zsh".source = ../resource/p10k.zsh;
  environment.variables.POWERLEVEL9K_CONFIG_FILE = "/etc/zsh/p10k.zsh";
}
