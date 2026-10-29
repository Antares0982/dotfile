{ lib, host }:
{
  name = "zsh-base";
  module = { };
  check =
    c:
    let
      darwin = host == "macbook";
      zsh = c.programs.zsh;
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
    && !(builtins.elem "powerlevel10k" packages)
    && !(c.environment.etc ? "zsh/p10k.zsh")
    && (
      if darwin then
        zsh.enableSyntaxHighlighting
        && zsh.enableAutosuggestions
        && !zsh.enableFzfCompletion
        && !zsh.enableFzfHistory
        && !zsh.enableFzfGit
      else
        zsh.syntaxHighlighting.enable
        && zsh.autosuggestions.enable
        && zsh.ohMyZsh.enable
        && c.programs.fzf.keybindings
        && c.programs.fzf.fuzzyCompletion
    )
    && (host != "nixos" || (home.enable && home.completionInit == "" && !(c.age.secrets ? ghToken)));
}
