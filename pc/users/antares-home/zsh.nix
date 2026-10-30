{
  pkgs,
  lib,
  ...
}:
let
  envs = pkgs.callPackage ./_env.nix { };
  genNixFunc = alias: packageName: ''
    ${alias}() { nix run nixpkgs#${packageName} -- "$@"; }
  '';
  nixFuncAliases = {
    cpuid = "cpuid";
    fastfetch = "fastfetch";
    killall = "killall";
    nix-update = "nix-update";
    python314 = "python314";
    python315 = "python315";
    ethtool = "ethtool";
  };
in
{
  programs.zsh = {
    enable = true;
    completionInit = "";
    shellAliases = {
      yt-dlp = "yt-dlp --cookies-from-browser chrome";
      shtreefmt = "fd -e sh -x shfmt -w";
    };
    initContent = ''
      export PATH=$PATH:${envs.envs.SCRIPT_DIR}:${envs.envs.SCRIPT_DIR}/linux

      # nix-zshell

      if [[ -n "$IN_NIX_SHELL" ]]; then
        label="nix-shell"
        if [[ "$name" != "$label" ]]; then
          label="$label:$name"
        fi
        export PS1=$'%{$fg[green]%}'"$label $PS1"
        unset label
      fi

      man2pdf(){
        man -t $1 | nix shell nixpkgs#ghostscript_headless -c ps2pdf - $1.pdf
      }

      unzip7zwithpass() {
        7z x "$1" -p$2
      }

      _f() {
        if [ "$#" -eq 0 ]; then
          echo "Need an arg."
          return 1
        fi

        if [[ ! -f flake.nix ]] || (( ! $+commands[nix] )); then
          command "$@"
          return
        fi

        local hasShell
        hasShell=$(nix eval --json --no-write-lock-file '.#.' \
          --apply 'flake: flake ? devShells.${pkgs.stdenv.hostPlatform.system}.default' \
          2>/dev/null)
        if [[ $? -eq 0 && "$hasShell" != true ]]; then
          command "$@"
          return
        fi

        local mark code reply
        mark=$(mktemp) || return 1
        nix develop -c ${pkgs.runtimeShell} -c 'printf 1 > "$1"; shift; exec "$@"' _ "$mark" "$@"
        code=$?
        if [[ -s "$mark" ]]; then
          rm -f "$mark"
          return $code
        fi

        rm -f "$mark"
        read -r "reply?nix develop failed. Run normally? [Y/n] " || return $code
        if [[ -z "$reply" || "$reply" == [Yy] ]]; then
          command "$@"
        else
          return $code
        fi
      }

      n() {
        _f nvim "$@"
      }

      _zz() {
        local cmd="$1"
        shift || return
        zi "$@" && "$cmd"
      }

      zn() { _zz n "$@"; }

      o() {
        _f opencode "$@"
      }

      zo() { _zz o "$@"; }

      c() {
        _f codex "$@"
      }

      zc() { _zz c "$@"; }

      op() {
        if [ "$#" -ne 1 ]; then
          echo "Usage: ns <file>"
          return 1
        fi
        local file
        file=$(realpath -- "$1" 2>/dev/null)
        if [ -z "$file" ]; then
          echo "ns: cannot resolve path: $1"
          return 1
        fi
        if [ ! -e "$file" ]; then
          echo "ns: file not found: $file"
          return 1
        fi
        niri msg action spawn -- xdg-open "$file"
      }

      nd() {
        if [ "$#" -eq 0 ]; then
          nix develop -c zsh
        else
          nix develop $@
        fi
      }

      ae() {
        cd "''${NIX_DOT_FILES:?NIX_DOT_FILES is not set}/secrets" || exit 1
        if [ "$#" -eq 0 ]; then
          echo "Usage: ae <file>"
          return 1
        fi
        agenix --identity /etc/ssh/agenix -e "$@"
      }
    ''
    + lib.concatStrings (lib.mapAttrsToList genNixFunc nixFuncAliases);
  };
}
