{
  config,
  lib,
  pkgs,
  linyinfeng-nur-packages,
  ...
}:
{
  imports = [ ../common/packages.nix ];
  # alphabet order
  environment.systemPackages = with pkgs; [
    actionlint
    android-tools
    aria2
    blender
    (callPackage ../packages/blender-mcp.nix { })
    cheat
    clang-tools
    cmake
    codex
    direnv
    # discord
    element-desktop
    ffmpeg
    google-chrome
    haruna
    imagemagick
    (callPackage ../packages/vtune.nix { })
    # kdePackages.dolphin
    kdePackages.gwenview
    kdePackages.kolourpaint
    # kdePackages.konsole
    libnotify
    # libreoffice
    neovim
    nixos-shell
    obsidian
    opencode
    openssl
    perf
    pyright
    qbittorrent
    ruff
    shfmt
    telegram-desktop
    thunderbird
    tor-browser
    tumbler
    typora
    unar
    xarchiver
    ydotool

  ];
}
