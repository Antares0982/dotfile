{ config, pkgs, ... }:
{
  environment.etc."zsh/rpi-p10k.zsh".source = ../resource/rpi-p10k.zsh;
}
