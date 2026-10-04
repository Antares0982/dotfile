{
  config,
  lib,
  pkgs,
  linyinfeng-nur-packages,
  inputs,
  ...
}:
let
  localPackages = import ../packages { inherit pkgs; };
  renewal = inputs.renewal.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
    nixos-shell
    opencode
    openssl
    perf
    pyright
    qbittorrent
    renewal
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
