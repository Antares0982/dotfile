{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;
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
    + lib.optionalString (config.environment.etc ? "zsh/p10k.zsh") ''
      [[ -f /etc/zsh/p10k.zsh ]] && source /etc/zsh/p10k.zsh
    ''
    + ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
  };
}
