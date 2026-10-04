{
  config,
  currentDevice,
  lib,
  pkgs,
  ...
}:
let
  darwin = lib.hasSuffix "-darwin" currentDevice.system;
  plugins = [
    "git"
    "sudo"
    "z"
  ];
  aliases =
    builtins.removeAttrs (import ./shellEnv.nix).aliases (
      lib.optionals darwin [
        "top"
        "ctl"
      ]
    )
    // {
      make = "make -j$(${pkgs.coreutils}/bin/nproc)";
    };
in
{
  environment.systemPackages = [
    pkgs.eza
    pkgs.gnumake
    pkgs.zsh-powerlevel10k
  ]
  ++ lib.optionals darwin [
    pkgs.oh-my-zsh
    pkgs.fzf
  ];

  programs = {
    zsh = {
      enable = true;
      enableGlobalCompInit = false;
    }
    // (
      if darwin then
        {
          enableSyntaxHighlighting = true;
          enableAutosuggestions = true;
          interactiveShellInit = ''
            export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
            ZSH_THEME=""
            ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
            mkdir -p "$ZSH_CACHE_DIR"
            plugins=(${lib.concatStringsSep " " plugins})
            source "$ZSH/oh-my-zsh.sh"
            source ${pkgs.fzf}/share/fzf/completion.zsh
            source ${pkgs.fzf}/share/fzf/key-bindings.zsh
          ''
          + lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: "alias -- ${lib.escapeShellArg "${name}=${value}"}") aliases
          );
        }
      else
        {
          shellAliases = aliases;
          syntaxHighlighting.enable = true;
          autosuggestions.enable = true;
          ohMyZsh = {
            enable = true;
            inherit plugins;
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
        }
    );
  }
  // lib.optionalAttrs (!darwin) {
    fzf = {
      keybindings = true;
      fuzzyCompletion = true;
    };
  };
}
