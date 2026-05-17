{
  config,
  pkgs,
  lib,
  my-kde-overlay,
  ...
}:
{
  lib.mkForce = {
    environment.variables = {
      #GTK_IM_MODULE = "fcitx";
      GTK_IM_MODULE = "wayland";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      SDL_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "ibus";
    };
  };
  nixpkgs.overlays = [
    my-kde-overlay
  ];
}
