{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.yazi.enable {
    programs = {
      yazi = {
        shellWrapperName = "y";
        settings.open.prepend_rules = [
          {
            # Compressed Blender files look like archives.
            url = "*.{blend,blender}";
            use = [
              "open"
              "reveal"
            ];
          }
        ];
        initLua = ''
          require("session"):setup {
            sync_yanked = true,
          }
        '';
      };
    };
    xdg.configFile."yazi/theme.toml".source = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/catppuccin/yazi/d62802be39210ea10e54b3e3b09735c6cb9e57c1/themes/macchiato/catppuccin-macchiato-mauve.toml";
      hash = "sha256-U2wqK7RgCM0D9ecjgmGB8K5yXt9wizCJEfnKhLDU3bk=";
    };
    xdg.configFile."yazi/Catppuccin-macchiato.tmTheme".source = pkgs.fetchurl {
      name = "Catppuccin-macchiato.tmTheme";
      url = "https://raw.githubusercontent.com/catppuccin/bat/6810349b28055dce54076712fc05fc68da4b8ec0/themes/Catppuccin%20Macchiato.tmTheme";
      hash = "sha256-EQCQ9lW5cOVp2C+zeAwWF2m1m6I0wpDQA5wejEm7WgY=";
    };
  };
}
