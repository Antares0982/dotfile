{ config, pkgs, ... }:
{
  environment.etc."zsh/p10k.zsh".source = ../resource/p10k.zsh;
  environment.variables.POWERLEVEL10K_CONFIG_FILE = "/etc/zsh/p10k.zsh";
}
