{ lib, host }:
lib.optionals
  (builtins.elem host [
    "nixos"
    "wsl"
  ])
  (
    map
      (enable: {
        name = if enable then "direnv-on" else "direnv-off";
        module = lib.optionalAttrs enable {
          programs.direnv.enable = lib.mkForce true;
        };
        check =
          c:
          c.programs.direnv.enable == enable
          && (builtins.elem "direnv" (map lib.getName c.environment.systemPackages)) == enable
          && (c.environment.etc ? "direnv/direnvrc") == enable
          && (c.environment.variables ? DIRENV_CONFIG) == enable
          && c.programs.direnv.enableZshIntegration;
      })
      [
        false
        true
      ]
  )
