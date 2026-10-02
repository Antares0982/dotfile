{
  config,
  lib,
  pkgs,
  linyinfeng-nur-packages,
  ...
}:
let
  localPackages = import ../packages { inherit pkgs; };
in
{
  imports = [ ../common/packages.nix ];
  # alphabet order
  environment.systemPackages = with pkgs; [
    actionlint
    android-tools
    aria2
    blender
    localPackages.blender-mcp
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
    localPackages.vtune
    # kdePackages.dolphin
    kdePackages.gwenview
    kdePackages.kolourpaint
    # kdePackages.konsole
    libnotify
    # libreoffice
    neovim
    nixos-shell
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
    umu-launcher
    unar
    vscode.fhs
    xarchiver

  ];
}
