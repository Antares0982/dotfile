{
  lib,
  config,
  osConfig,
  ...
}:
{
  config = lib.mkIf (osConfig.antares.desktop.enable) {

    xdg = {
      configFile."xdg-terminals.list".text = "kitty.desktop\n";
      mimeApps = {
        enable = true;
        associations.added = {
          "application/x-zerosize" = [ "nvim.desktop" ];
          "application/yaml" = [ "nvim.desktop" ];
          "image/gif" = [ "org.kde.gwenview.desktop" ];
          "image/jpeg" = [ "org.kde.gwenview.desktop" ];
          "image/png" = [ "org.kde.gwenview.desktop" ];
          "image/webp" = [ "org.kde.gwenview.desktop" ];
          "image/svg+xml" = [ "google-chrome.desktop" ];
          "text/markdown" = [ "typora.desktop" ];
          "text/plain" = [ "nvim.desktop" ];
          "application/x-shellscript" = [ "nvim.desktop" ];
          "x-scheme-handler/baiduyunguanjia" = [ "baidunetdisk.desktop" ];
          "x-scheme-handler/http" = [ "google-chrome.desktop" ];
          "x-scheme-handler/https" = [ "google-chrome.desktop" ];
          "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
          "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
        };
        associations.removed = {
          "application/vnd.ms-publisher" = [ "draw.desktop" ];
        };
        defaultApplications = {
          "application/x-zerosize" = [ "nvim.desktop" ];
          "application/yaml" = [ "nvim.desktop" ];
          "image/gif" = [ "org.kde.gwenview.desktop" ];
          "image/jpeg" = [ "org.kde.gwenview.desktop" ];
          "image/png" = [ "org.kde.gwenview.desktop" ];
          "image/webp" = [ "org.kde.gwenview.desktop" ];
          "image/svg+xml" = [ "google-chrome.desktop" ];
          "text/html" = [ "google-chrome.desktop" ];
          "text/markdown" = [ "typora.desktop" ];
          "text/plain" = [ "nvim.desktop" ];
          "video/matroska" = [ "org.kde.haruna.desktop" ];
          "video/matroska-3d" = [ "org.kde.haruna.desktop" ];
          "video/mp2t" = [ "org.kde.haruna.desktop" ];
          "video/mp4" = [ "org.kde.haruna.desktop" ];
          "video/mpeg" = [ "org.kde.haruna.desktop" ];
          "video/ogg" = [ "org.kde.haruna.desktop" ];
          "video/quicktime" = [ "org.kde.haruna.desktop" ];
          "video/vnd.avi" = [ "org.kde.haruna.desktop" ];
          "video/webm" = [ "org.kde.haruna.desktop" ];
          "video/x-matroska" = [ "org.kde.haruna.desktop" ];
          "video/x-matroska-3d" = [ "org.kde.haruna.desktop" ];
          "video/x-ms-wmv" = [ "org.kde.haruna.desktop" ];
          "video/x-msvideo" = [ "org.kde.haruna.desktop" ];
          "application/x-shellscript" = [ "nvim.desktop" ];
          "x-scheme-handler/baiduyunguanjia" = [ "baidunetdisk.desktop" ];
          "x-scheme-handler/http" = [ "google-chrome.desktop" ];
          "x-scheme-handler/https" = [ "google-chrome.desktop" ];
          "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
          "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
        };
      };
    };

  };
}
