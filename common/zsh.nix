{ config, pkgs, currentDevice, ... }:
{
  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "z"
      ];
    };
    promptInit = ''
      POWERLEVEL10K_MODE=nerdfont-complete
    '' + (if currentDevice.rpi then ''
      [[ -f /etc/zsh/rpi-p10k.zsh ]] && source /etc/zsh/rpi-p10k.zsh
    '' else "") + ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
  };
}
