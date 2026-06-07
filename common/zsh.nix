{
  config,
  lib,
  pkgs,
  currentDevice,
  ...
}:
(
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
      ''
      + (lib.optionalString (currentDevice.rpi || (currentDevice.server.hk or false)) ''
        [[ -f /etc/zsh/p10k.zsh ]] && source /etc/zsh/p10k.zsh
      '')
      + ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';
    };
  }
  // lib.optionalAttrs currentDevice.rpi {
    environment.etc."zsh/p10k.zsh".source = ../resource/rpi-p10k.zsh;
  }
  // lib.optionalAttrs (currentDevice.server.hk or false) {
    environment.etc."zsh/p10k.zsh".source = ../resource/hk-p10k.zsh;
  }
)
