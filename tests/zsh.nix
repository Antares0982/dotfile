{ lib, host }:
{
  name = "zsh-base";
  module = { };
  check =
    c:
    let
      darwin = host == "macbook";
      zsh = c.programs.zsh;
      rc = c.environment.etc.zshrc.text;
      packages = map lib.getName c.environment.systemPackages;
      home = if host == "nixos" then c.home-manager.users.antares.programs.zsh else null;
      theme = c.environment.etc."zsh/p10k.zsh".source or null;
    in
    zsh.enable
    && !zsh.enableGlobalCompInit
    && lib.all (name: builtins.elem name packages) [
      "zsh"
      "oh-my-zsh"
      "fzf"
      "eza"
      "gnumake"
      "powerlevel10k"
    ]
    && !(lib.hasInfix "fzf" zsh.shellInit)
    && !(lib.hasInfix "fzf" zsh.loginShellInit)
    && !(lib.hasInfix "autoload -U compinit && compinit" rc)
    && (
      if darwin then
        zsh.enableSyntaxHighlighting
        && zsh.enableAutosuggestions
        && !zsh.enableFzfCompletion
        && !zsh.enableFzfHistory
        && !zsh.enableFzfGit
        && lib.hasInfix "plugins=(git sudo z)" rc
        && lib.hasInfix "/share/fzf/completion.zsh" rc
        && lib.hasInfix "/share/fzf/key-bindings.zsh" rc
        && lib.hasInfix "alias -- 'ls=eza'" rc
        && !(lib.hasInfix "systemctl" rc)
        && !(lib.hasInfix "top -d" rc)
        && !(lib.hasInfix "powerlevel10k.zsh-theme" rc)
      else
        zsh.syntaxHighlighting.enable
        && zsh.autosuggestions.enable
        && zsh.ohMyZsh.enable
        &&
          lib.sort builtins.lessThan zsh.ohMyZsh.plugins == [
            "fzf"
            "git"
            "sudo"
            "z"
          ]
        && c.programs.fzf.keybindings
        && c.programs.fzf.fuzzyCompletion
        && zsh.shellAliases.ls == "eza"
        && zsh.shellAliases.ctl == "systemctl --user"
        && lib.hasInfix "/bin/nproc" zsh.shellAliases.make
        && lib.hasInfix "powerlevel10k.zsh-theme" rc
    )
    && (
      if
        builtins.elem host [
          "hk"
          "gz"
          "sz"
        ]
      then
        builtins.readFile theme == builtins.readFile ../resource/hk-p10k.zsh
      else if host == "rpi5" then
        builtins.readFile theme == builtins.readFile ../resource/rpi-p10k.zsh
      else
        theme == null
    )
    && (
      host != "nixos"
      || (
        home.enable
        && home.completionInit == ""
        && lib.matchAttrs {
          sctl = "sudo systemctl";
          jtl = "journalctl --user";
          sjtl = "sudo journalctl";
        } home.shellAliases
        && !(home.shellAliases ? ctl)
        && lib.all (text: lib.hasInfix text home.initContent) [
          "[[ ! -f \"/home/antares/.p10k.zsh\" ]]"
          "direnv hook zsh"
          "command yazi"
          "_f()"
          "op()"
          "nd()"
          "cpuid()"
          "python315()"
        ]
      )
    );
}
