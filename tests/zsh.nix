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
    in
    zsh.enable
    && !zsh.enableGlobalCompInit
    && lib.all (name: builtins.elem name packages) [
      "zsh"
      "oh-my-zsh"
      "fzf"
      "eza"
      "gnumake"
    ]
    && !(lib.hasInfix "fzf" zsh.shellInit)
    && !(lib.hasInfix "fzf" zsh.loginShellInit)
    && !(lib.hasInfix "autoload -U compinit && compinit" rc)
    && !(builtins.elem "powerlevel10k" packages)
    && !(lib.hasInfix "p10k" rc)
    && !(lib.hasInfix "powerlevel10k" rc)
    && !(c.environment.etc ? "zsh/p10k.zsh")
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
        && lib.hasInfix "alias -- 'nixtreefmt=" rc
        && !(lib.hasInfix "systemctl" rc)
        && !(lib.hasInfix "top -d" rc)
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
        && lib.hasInfix "/bin/fd -t f -e nix -x " zsh.shellAliases.nixtreefmt
        && lib.hasInfix "/bin/nproc" zsh.shellAliases.make
    )
    && (
      host != "nixos"
      || (
        home.enable
        && home.completionInit == ""
        && !(c.age.secrets ? ghToken)
        && !(lib.hasInfix "GH_TOKEN" home.initContent)
        && !(lib.hasInfix "p10k" home.initContent)
        && lib.matchAttrs {
          sctl = "sudo systemctl";
          jtl = "journalctl --user";
          sjtl = "sudo journalctl";
        } home.shellAliases
        && !(home.shellAliases ? ctl)
        && !(home.shellAliases ? nixtreefmt)
        && lib.all (text: lib.hasInfix text home.initContent) [
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
