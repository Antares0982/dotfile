{ lib, host }:
let
  homes = c: builtins.attrValues (c.home-manager.users or { });
  colors = {
    nixos = "#00af00";
    macbook = "#ff5faf";
    rpi5 = "#8700d7";
    hk = "#ff8700";
    gz = "#ff8700";
    sz = "#ff8700";
    wsl = "#005faf";
  };
in
[
  {
    name = "starship-on";
    module = { };
    check =
      c:
      let
        settings = c.antares.starship.settings;
        zsh = c.programs.zsh;
      in
      c.antares.starship.enable
      && c.environment.etc ? "starship.toml"
      && builtins.elem "starship" (map lib.getName c.environment.systemPackages)
      && settings.palette == "host"
      && settings.directory.style == "fg:color_fg0 bg:color_yellow"
      && settings.directory.read_only_style == "fg:color_fg0 bg:color_yellow"
      && settings.palettes.host.color_os == colors.${host}
      && lib.hasInfix "[](bg:color_yellow fg:color_os)$directory[](fg:color_yellow bg:color_aqua)" settings.format
      && lib.hasInfix "$line_break$character" settings.format
      && settings.palettes.host.color_fg0 == "#fbf1c7"
      && settings.palettes.host.color_yellow == "#d79921"
      && !(settings.palettes.host ? cwd_bg)
      && !(settings.palettes.host ? cwd_fg)
      && lib.hasPrefix "[](color_os)$os$username" settings.format
      && settings.os.style == "bg:color_os fg:color_fg0"
      && settings.username.style_user == "bg:color_os fg:color_fg0"
      && settings.username.style_root == "bg:color_os fg:color_fg0"
      && !settings.os.disabled
      && settings.username.show_always
      && !settings.time.disabled
      && settings.directory.format == "[ $path]($style)[$read_only]($read_only_style)[ ]($style)"
      && settings.directory.truncation_length == 3
      && settings.directory.fish_style_pwd_dir_length == 1
      && settings.directory.home_symbol == "~"
      && (settings.directory.substitutions or { }) == { }
      && lib.hasInfix "export STARSHIP_CONFIG=/etc/starship.toml" zsh.interactiveShellInit
      && lib.hasInfix "$TERM != dumb" zsh.promptInit
      && lib.hasInfix "/bin/starship init zsh" zsh.promptInit
      && !(lib.hasInfix "starship" zsh.shellInit)
      && !(lib.hasInfix "starship" zsh.loginShellInit)
      && lib.all (
        home:
        home.programs.zsh.enable
        && home.programs.zsh.completionInit == ""
        && home.programs.starship.enable
        && home.programs.starship.enableZshIntegration
        && !home.programs.starship.enableBashIntegration
        && home.programs.starship.configPath == "/etc/starship.toml"
        && home.programs.starship.settings == { }
        && home.home.sessionVariables.STARSHIP_CONFIG == "/etc/starship.toml"
        && !(home.home.file ? "/etc/starship.toml")
        && !(home.xdg.configFile ? "starship.toml")
        && lib.hasInfix "/bin/starship init zsh" home.programs.zsh.initContent
        && lib.hasInfix "${lib.escapeShellArg home.home.username}) ;;" zsh.promptInit
      ) (homes c);
  }
  {
    name = "starship-off";
    module.antares.starship.enable = lib.mkForce false;
    check =
      c:
      !(c.environment.etc ? "starship.toml")
      && !(builtins.elem "starship" (map lib.getName c.environment.systemPackages))
      && !(lib.hasInfix "starship" c.environment.etc.zshrc.text)
      && !(c.environment.etc ? "zsh/p10k.zsh")
      && lib.all (
        home:
        !home.programs.starship.enable
        && !(home.home.sessionVariables ? STARSHIP_CONFIG)
        && !(lib.hasInfix "starship" home.programs.zsh.initContent)
      ) (homes c);
  }
  {
    name = "starship-overrides";
    module.antares.starship.settings = {
      format = "$directory$character";
      directory.style = "bold blue";
      directory.truncation_length = 5;
      directory.fish_style_pwd_dir_length = 2;
      add_newline = false;
    };
    check =
      c:
      let
        settings = c.antares.starship.settings;
      in
      settings.directory.style == "bold blue"
      && settings.format == "$directory$character"
      && settings.directory.truncation_length == 5
      && settings.directory.fish_style_pwd_dir_length == 2
      && settings.directory.home_symbol == "~"
      && settings.directory.read_only_style == "fg:color_fg0 bg:color_yellow"
      && settings.palettes.host.color_os == colors.${host}
      && !settings.add_newline;
  }
]
