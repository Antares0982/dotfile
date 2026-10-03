{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  fcitx = osConfig.i18n.inputMethod.enable && osConfig.i18n.inputMethod.type == "fcitx5";
in
{
  config = lib.mkIf osConfig.antares.desktop.enable {
    xdg.configFile = {
      "kitty/kitty.conf".text = ''
        font_family FiraCode Nerd Font
        font_size 14.0

        mouse_map left click ungrabbed mouse_handle_click selection
        mouse_map ctrl+left click ungrabbed mouse_handle_click selection link
      ''
      + lib.optionalString fcitx ''

        watcher fcitx5.py
      '';
      "kitty/fcitx5.py" = lib.mkIf fcitx {
        source = pkgs.replaceVars ./kitty-fcitx5.py {
          fcitx5_remote = "${pkgs.fcitx5}/bin/fcitx5-remote";
        };
      };
    };
  };
}
