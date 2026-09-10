{ pkgs, lib, ... }:
let
  commonEnv = import ../../../common/shellEnv.nix;
  localFileDef = import ../../../common/localFileDef.nix {
    username = "antares";
  };
  nix-zshell = pkgs.callPackage ./../../../common/_nix-zshell.nix { };
  genNixFunc = alias: packageName: ''
    ${alias}() { nix run nixpkgs#${packageName} -- "$@"; }
  '';
  nixFuncAliases = {
    cpuid = "cpuid";
    fastfetch = "fastfetch";
    killall = "killall";
    nix-update = "nix-update";
    python313 = "python313";
    python314 = "python314";
    python315 = "python315";
    ethtool = "ethtool";
  };
in
rec {
  inherit localFileDef;
  inherit (localFileDef) username userhome;
  inherit (commonEnv) sysBin;
  usernameCap = "Antares";
  envs = rec {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
    GITHUB_DIR = localFileDef.githubDir;
    SCRIPT_DIR = localFileDef.scriptDir;
    XRAY_CONF_DIR = localFileDef.xrayConfDir;
    XRAY_CONFIG_PATH = localFileDef.xrayConfPath;
    XRAY_TEMPLATE = localFileDef.xrayConfTemplatePath;
    GPG_TTY = "$TTY";
    NIX_BUILD_SHELL = "${nix-zshell}/bin/nix-zshell";
    NIX_DOT_FILES = "${localFileDef.docDir}/Nix";
    EDITOR = "nvim";
  };
  aliases = commonEnv.aliases // {
    yt-dlp = "yt-dlp --cookies-from-browser chrome";
    chrome_no_proxy = "nohup google-chrome-stable --proxy-server=\"http://127.0.0.1:1083\" --user-data-dir=$HOME/.config/google-chrome-no-proxy &>/dev/null & disown";
    nixtreefmt = "fd -e nix -x nixfmt";
    ctl = "systemctl --user";
    sctl = "sudo systemctl";
    ctlr = "ctl restart";
    sctlr = "sctl restart";
    ctls = "ctl status";
    sctls = "sctl status";
    ctlc = "ctl cat";
    sctlc = "sctl cat";
  };
  escapebrace = "$" + "{";
  shellInitExtra = ''
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

    _nix_py_init() {
      local tmpdir
      tmpdir=$(mktemp -d) || return 1
      git clone --depth 1 https://github.com/Antares0982/nix-pyenv "$tmpdir" 2>/dev/null || { rm -rf "$tmpdir"; echo "clone failed"; return 1; }
      local copied=() skipped=()
      for f in "$tmpdir"/*.nix; do
        local name=$(basename "$f")
        if [[ -e "$name" ]]; then
          skipped+=("$name")
        else
          cp "$f" . && copied+=("$name")
        fi
      done
      rm -rf "$tmpdir"
      (( ${escapebrace}#copied[@]} )) && echo "copied: ${escapebrace}copied[*]}"
      (( ${escapebrace}#skipped[@]} )) && echo "skipped (already exists): ${escapebrace}skipped[*]}"
      if git rev-parse --is-inside-work-tree &>/dev/null && (( ${escapebrace}#copied[@]} )); then
        git add "${escapebrace}copied[@]}" && echo "git add done"
      fi
    }

    export GH_TOKEN=$(cat /run/agenix/ghToken)

    unzip7zwithpass() {
      nix run nixpkgs#p7zip -- x "$1" -p$2
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
      hasShell=$(nix eval --impure --json --expr '
        let
          flake = builtins.getFlake (toString ./.);
          system = builtins.currentSystem;
        in
          flake.outputs ? devShells
          && builtins.hasAttr system flake.outputs.devShells
          && builtins.hasAttr "default" (builtins.getAttr system flake.outputs.devShells)
      ' 2>/dev/null)
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
      if [ "$#" -lt 2 ]; then
        echo "Need an arg."
        return 1
      fi
      local cmd="$1"
      shift
      z "$1" && "$cmd"
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
  ''
  + lib.concatStrings (lib.mapAttrsToList genNixFunc nixFuncAliases);
}
