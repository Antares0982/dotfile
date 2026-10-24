{
  config,
  currentDevice,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.antares.starship;
  toml = pkgs.formats.toml { };
  managedUsers = if currentDevice.withHm then builtins.attrNames config.home-manager.users else [ ];
in
{
  options.antares.starship = {
    enable = lib.mkEnableOption "the managed Starship prompt";
    settings = lib.mkOption {
      type = toml.type;
      default = { };
      apply = lib.recursiveUpdate {
        palette = "host";
        palettes.host = {
          cwd_bg = "#00af00";
          cwd_fg = "#000000";
        };
        directory = {
          style = "bold fg:cwd_fg bg:cwd_bg";
          read_only_style = "fg:cwd_fg bg:cwd_bg";
        };
      };
      description = "Starship settings recursively overriding the shared defaults.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      environment.systemPackages = [ pkgs.starship ];
      environment.etc."starship.toml".source = toml.generate "starship.toml" cfg.settings;
      programs.zsh = {
        interactiveShellInit = lib.mkBefore ''
          export STARSHIP_CONFIG=/etc/starship.toml
        '';
        promptInit = ''
          if [[ $TERM != dumb ]]; then
            ${
              if managedUsers == [ ] then
                ''eval "$(${pkgs.starship}/bin/starship init zsh)"''
              else
                ''
                  case "$USERNAME" in
                    ${lib.concatMapStringsSep "|" lib.escapeShellArg managedUsers}) ;;
                    *) eval "$(${pkgs.starship}/bin/starship init zsh)" ;;
                  esac
                ''
            }
          fi
        '';
      };
    }
    // lib.optionalAttrs currentDevice.withHm {
      home-manager.sharedModules = [
        {
          programs.zsh = {
            enable = true;
            completionInit = lib.mkDefault "";
          };
          programs.starship = {
            enable = true;
            configPath = "/etc/starship.toml";
            enableZshIntegration = true;
            enableBashIntegration = false;
            enableFishIntegration = false;
            enableIonIntegration = false;
            enableNushellIntegration = false;
          };
        }
      ];
    }
  );
}
