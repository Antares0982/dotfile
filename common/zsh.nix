{
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
  formatNixFile = pkgs.writeShellScript "nixtreefmt-file" ''
    if ! ${pkgs.nixfmt}/bin/nixfmt --check --quiet "$1"; then
      ${pkgs.nixfmt}/bin/nixfmt "$1" && printf '%s\n' "$1"
    fi
  '';
  aliases =
    builtins.removeAttrs (import ./shellEnv.nix).aliases (
      lib.optionals darwin [
        "top"
        "ctl"
      ]
    )
    // {
      make = "make -j$(${pkgs.coreutils}/bin/nproc)";
      cat = "bat -pp";
      nixtreefmt = "${pkgs.fd}/bin/fd -t f -e nix -x ${formatNixFile}";
    };
in
{
  imports = [ ../modules/starship.nix ];

  environment.systemPackages = [
    pkgs.eza
    pkgs.gnumake
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
