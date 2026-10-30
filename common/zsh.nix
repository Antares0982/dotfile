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
  ];
  formatNixFile = pkgs.writeShellScript "nixtreefmt-file" ''
    if ! ${pkgs.nixfmt}/bin/nixfmt --check --quiet "$1"; then
      ${pkgs.nixfmt}/bin/nixfmt "$1" && printf '%s\n' "$1"
    fi
  '';
  aliases =
    builtins.removeAttrs (import ./shellEnv.nix).aliases (lib.optionals darwin [ "top" ])
    // {
      cat = "bat -pp";
      nixtreefmt = "${pkgs.fd}/bin/fd -t f -e nix -x ${formatNixFile}";
    }
    // lib.optionalAttrs (!darwin) {
      ctl = "systemctl --user";
      sctl = "sudo systemctl";
      ctlr = "ctl restart";
      sctlr = "sctl restart";
      ctls = "ctl status";
      sctls = "sctl status";
      ctlc = "ctl cat";
      sctlc = "sctl cat";
      jtl = "journalctl --user";
      sjtl = "sudo journalctl";
      jtlu = "jtl -u";
      sjtlu = "sjtl -u";
      jtleu = "jtl -e -u";
      sjtleu = "sjtl -e -u";
      jtlb = "jtl -b";
      sjtlb = "sjtl -b";
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
    pkgs.zoxide
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
            eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
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
    zoxide.enable = true;
    fzf = {
      keybindings = true;
      fuzzyCompletion = true;
    };
  };
}
