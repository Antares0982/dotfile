{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.antares.windowsShell;
  commands =
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = "${name}.exe";
        })
        [
          "git"
          "gh"
          "uv"
          "uvx"
          "python"
          "rg"
          "fd"
          "fzf"
          "eza"
          "nvim"
          "delta"
          "jq"
          "yazi"
          "ya"
          "7z"
          "ffmpeg"
          "ffprobe"
          "magick"
          "node"
          "ruff"
          "winget"
          "explorer"
          "clip"
          "cmd"
          "powershell"
          "pwsh"
          "wt"
        ]
    )
    // {
      python3 = "python.exe";
    };
  npmLauncher =
    name:
    pkgs.writeShellScriptBin name ''
      node=$(command -v node.exe) || { echo '${name}: node.exe not found' >&2; exit 127; }
      node=$(${pkgs.coreutils}/bin/readlink -f -- "$node") || exit
      script=$(wslpath -w "''${node%/*}/node_modules/npm/bin/${name}-cli.js") || exit
      exec "$node" "$script" "$@"
    '';
  launchers = pkgs.buildEnv {
    name = "windows-shell-commands";
    paths =
      (lib.mapAttrsToList (
        name: target:
        pkgs.writeShellScriptBin name ''
          exec ${target} "$@"
        ''
      ) commands)
      ++ map npmLauncher [
        "npm"
        "npx"
      ];
    pathsToLink = [ "/bin" ];
  };
  linuxShell = pkgs.writeShellScriptBin "linux-shell" ''
    if [[ -v _ANTARES_WS_PATH ]]; then
      export PATH="$_ANTARES_WS_PATH"
      if [[ -n ''${_ANTARES_WS_ZOXIDE-} ]]; then
        export _ZO_DATA_DIR="$_ANTARES_WS_ZOXIDE"
      else
        unset _ZO_DATA_DIR
      fi
    fi
    unset AS_WINDOWS_SHELL _ANTARES_WS_PATH _ANTARES_WS_ZOXIDE
    unset STARSHIP_CONFIG ZSH_CACHE_DIR ZSH_COMPDUMP HISTFILE
    if [[ $# == 0 ]]; then
      exec ${pkgs.zsh}/bin/zsh
    fi
    exec "$@"
  '';
  runtimeLinks = pkgs.runCommand "windows-shell-runtime-tools" { } ''
    mkdir -p "$out/bin"
    ln -s /run/wrappers/bin/sudo "$out/bin/sudo"
    ln -s /bin/wslpath "$out/bin/wslpath"
  '';
  native = pkgs.buildEnv {
    name = "windows-shell-linux-tools";
    paths =
      (with pkgs; [
        bashInteractive
        zsh
        coreutils
        gnugrep
        gnused
        gawk
        less
        bat
        zoxide
        file
        ncurses
        hostname
        glibc.bin
        nix
        nixos-rebuild
        systemd
        procps
        openssh
      ])
      ++ [
        runtimeLinks
        linuxShell
      ]
      ++ lib.optional config.antares.starship.enable pkgs.starship;
    pathsToLink = [ "/bin" ];
  };
  # Starship's WSL adapter falls back to Linux if spawning its target fails.
  # A permanent Linux launcher always starts, even if starship.exe is missing;
  # empty stdout then hides the module instead of computing Linux Git status.
  windowsStarship = pkgs.writeShellScript "windows-starship" ''
    exec starship.exe "$@"
  '';
  toml = pkgs.formats.toml { };
  promptSettings = {
    format = "[](#0078D4)[ 󰍲 ](fg:#fbf1c7 bg:#0078D4)[](fg:#0078D4 bg:#d79921)$directory[](#d79921)$git_status$line_break$character";
    directory = {
      format = "[ $path ]($style)";
      style = "fg:#3c3836 bg:#d79921";
      truncate_to_repo = false;
      truncation_length = 3;
      fish_style_pwd_dir_length = 1;
      use_logical_path = true;
    };
    git_status = {
      windows_starship = "${windowsStarship}";
      format = "([ $all_status$ahead_behind]($style))";
      style = "fg:#83a598";
    };
  };
  plainPrompt = toml.generate "windows-shell-starship.toml" (
    lib.recursiveUpdate promptSettings { git_status.disabled = true; }
  );
  gitPrompt = toml.generate "windows-shell-starship-git.toml" promptSettings;
  envScript = pkgs.replaceVars ../resource/windows-shell/env.zsh {
    commands = "${launchers}/bin";
    native = "${native}/bin";
    mountRoot = lib.escapeShellArg (config.wsl.wslConf.automount.root or "/mnt");
  };
  interactiveScript = pkgs.replaceVars ../resource/windows-shell/interactive.zsh {
    starshipEnabled = if config.antares.starship.enable then "1" else "0";
    inherit plainPrompt gitPrompt;
  };
in
{
  options.antares.windowsShell.enable = lib.mkEnableOption "the opt-in WSL Windows shell profile";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.wsl.enable;
        message = "antares.windowsShell requires NixOS-WSL.";
      }
    ];
    system.build.windowsShell = pkgs.linkFarm "windows-shell" [
      {
        name = "zshrc";
        path = config.environment.etc.zshrc.source;
      }
      {
        name = "commands";
        path = launchers;
      }
      {
        name = "native";
        path = native;
      }
      {
        name = "env.zsh";
        path = envScript;
      }
      {
        name = "interactive.zsh";
        path = interactiveScript;
      }
    ];
    environment.etc = {
      "windows-shell/env.zsh".source = envScript;
      "windows-shell/interactive.zsh".source = interactiveScript;
    }
    // lib.optionalAttrs config.antares.starship.enable {
      "windows-shell/starship.toml".source = plainPrompt;
      "windows-shell/starship-git.toml".source = gitPrompt;
    };
    programs.zsh = {
      # Also applies to zsh -c and inherited noninteractive subprocesses.
      shellInit = lib.mkAfter "source ${envScript}";
      loginShellInit = lib.mkAfter "source ${envScript}";
      interactiveShellInit = lib.mkOrder 400 ''
        source ${envScript}
        if [[ ''${AS_WINDOWS_SHELL-} == 1 ]]; then
          HISTFILE="''${XDG_STATE_HOME:-$HOME/.local/state}/windows-shell/zsh_history"
          typeset +x HISTFILE
          mkdir -p -m 700 -- "''${HISTFILE:h}" "$_ZO_DATA_DIR"
        fi
      '';
      ohMyZsh.preLoaded = lib.mkBefore ''
        if [[ ''${AS_WINDOWS_SHELL-} == 1 ]]; then
          plugins=(''${plugins:#fzf})
          ZSH_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/windows-shell/oh-my-zsh"
          mkdir -p -m 700 -- "$ZSH_CACHE_DIR"
          ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump-$ZSH_VERSION"
          typeset +x ZSH_CACHE_DIR ZSH_COMPDUMP
        fi
      '';
      # Runs after aliases and all interactive integrations, before Starship init.
      promptInit = lib.mkBefore ''
        if [[ ''${AS_WINDOWS_SHELL-} == 1 ]]; then
          unalias nixtreefmt 2>/dev/null
          source ${interactiveScript}
        fi
      '';
    };
  };
}
