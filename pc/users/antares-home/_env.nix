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
  };
  aliases = commonEnv.aliases // {
    yt-dlp = "yt-dlp --cookies-from-browser chrome";
    chrome_no_proxy = "nohup google-chrome-stable --proxy-server=\"http://127.0.0.1:1083\" --user-data-dir=$HOME/.config/google-chrome-no-proxy &>/dev/null & disown";
    nixtreefmt = "fd -e nix -x nixfmt";
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
      if [[ -f flake.nix ]] && grep -q 'devShell' flake.nix; then
        nix develop -c $@
      else
        command $@
      fi
    }

    n() {
      _f nvim $@
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
      _f opencode $@
    }

    zo() { _zz o "$@"; }

    c() {
      _f claude $@
    }

    zc() { _zz c "$@"; }

    export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
    export ANTHROPIC_AUTH_TOKEN=$(cat /run/agenix/deepseekAPIKey)
    export ANTHROPIC_MODEL=deepseek-v4-pro[1m]
    export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]
    export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro[1m]
    export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
    export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
    export CLAUDE_CODE_EFFORT_LEVEL=max
  ''
  + lib.concatStrings (lib.mapAttrsToList genNixFunc nixFuncAliases);
}
