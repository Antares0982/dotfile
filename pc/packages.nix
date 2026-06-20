{
  config,
  lib,
  pkgs,
  linyinfeng-nur-packages,
  ...
}:
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = with pkgs; [
    android-tools
    aria2
    basedpyright
    cheat
    clang-tools
    claude-code
    cmake
    direnv
    # discord
    ffmpeg
    imagemagick
    # kdePackages.dolphin
    kdePackages.gwenview
    # kdePackages.konsole
    libnotify
    # libreoffice
    neovim
    nixos-shell
    obsidian
    opencode
    openspec
    openssl
    perf
    pyright
    qbittorrent
    ruff
    shfmt
    steamcmd
    steam-run
    telegram-desktop
    thunderbird
    tor-browser
    tumbler
    unar
    xarchiver
    ydotool

    # niri ecosystem
    fuzzel
    grim
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kitty
    lxqt.lxqt-policykit
    mako
    pavucontrol
    slurp
    swaylock
    swaybg
    thunar
    thunar-archive-plugin
    waybar
    wl-clipboard
  ];
}
