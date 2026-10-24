{ lib, host }:
let
  homes = c: builtins.attrValues (c.home-manager.users or { });
  colors = {
    nixos = [
      "#00af00"
      "#000000"
    ];
    macbook = [
      "#ff5faf"
      "#000000"
    ];
    rpi5 = [
      "#8700d7"
      "#ffffff"
    ];
    hk = [
      "#ff8700"
      "#000000"
    ];
    gz = [
      "#ff8700"
      "#000000"
    ];
    sz = [
      "#ff8700"
      "#000000"
    ];
    wsl = [
      "#005faf"
      "#ffffff"
    ];
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
      && settings.directory.style == "bold fg:cwd_fg bg:cwd_bg"
      && settings.directory.read_only_style == "fg:cwd_fg bg:cwd_bg"
      && settings.palettes.host.cwd_bg == builtins.elemAt colors.${host} 0
      && settings.palettes.host.cwd_fg == builtins.elemAt colors.${host} 1
      && lib.hasInfix "[](bg:cwd_bg fg:color_orange)$directory[](fg:cwd_bg bg:color_aqua)" settings.format
      && lib.hasInfix "$line_break$character" settings.format
      && settings.palettes.host.color_fg0 == "#fbf1c7"
      && !settings.os.disabled
      && settings.username.show_always
      && !settings.time.disabled
      && settings.directory.format == "[ $path]($style)[$read_only]($read_only_style)[ ]($style)"
      && settings.directory.truncation_length == 3
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
      directory.substitutions.Documents = "Docs";
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
      && settings.directory.substitutions.Documents == "Docs"
      && settings.directory.substitutions.Downloads == " "
      && settings.directory.read_only_style == "fg:cwd_fg bg:cwd_bg"
      && settings.palettes.host.cwd_bg == builtins.elemAt colors.${host} 0
      && !settings.add_newline;
  }
]
