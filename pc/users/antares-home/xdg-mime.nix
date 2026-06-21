{ ... }:
{
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "application/x-zerosize"           = [ "nvim.desktop" ];
      "application/yaml"                 = [ "nvim.desktop" ];
      "image/gif"                        = [ "org.kde.gwenview.desktop" ];
      "image/jpeg"                       = [ "org.kde.gwenview.desktop" ];
      "image/png"                        = [ "org.kde.gwenview.desktop" ];
      "image/svg+xml"                    = [ "google-chrome.desktop" ];
      "text/markdown"                    = [ "typora.desktop" ];
      "text/plain"                       = [ "nvim.desktop" ];
      "application/x-shellscript"        = [ "nvim.desktop" ];
      "x-scheme-handler/baiduyunguanjia" = [ "baidunetdisk.desktop" ];
      "x-scheme-handler/claude-cli"      = [ "claude-code-url-handler.desktop" ];
      "x-scheme-handler/http"            = [ "google-chrome.desktop" ];
      "x-scheme-handler/https"           = [ "google-chrome.desktop" ];
      "x-scheme-handler/tg"              = [ "org.telegram.desktop.desktop" ];
      "x-scheme-handler/tonsite"         = [ "org.telegram.desktop.desktop" ];
    };
    associations.removed = {
      "application/vnd.ms-publisher" = [ "draw.desktop" ];
    };
    defaultApplications = {
      "application/x-zerosize"           = [ "nvim.desktop" ];
      "application/yaml"                 = [ "nvim.desktop" ];
      "image/gif"                        = [ "org.kde.gwenview.desktop" ];
      "image/jpeg"                       = [ "org.kde.gwenview.desktop" ];
      "image/png"                        = [ "org.kde.gwenview.desktop" ];
      "image/svg+xml"                    = [ "google-chrome.desktop" ];
      "text/html"                        = [ "google-chrome.desktop" ];
      "text/markdown"                    = [ "typora.desktop" ];
      "text/plain"                       = [ "nvim.desktop" ];
      "application/x-shellscript"        = [ "nvim.desktop" ];
      "x-scheme-handler/baiduyunguanjia" = [ "baidunetdisk.desktop" ];
      "x-scheme-handler/claude-cli"      = [ "claude-code-url-handler.desktop" ];
      "x-scheme-handler/http"            = [ "google-chrome.desktop" ];
      "x-scheme-handler/https"           = [ "google-chrome.desktop" ];
      "x-scheme-handler/tg"              = [ "org.telegram.desktop.desktop" ];
      "x-scheme-handler/tonsite"         = [ "org.telegram.desktop.desktop" ];
    };
  };
}
