{
  config,
  lib,
  pkgs,
  linyinfeng-nur-packages,
  ...
}:
{
  imports = [ ../common/packages.nix ];
  environment.systemPackages = (
    with pkgs;
    [
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
      kdePackages.dolphin
      kdePackages.gwenview
      kdePackages.konsole
      libnotify
      libreoffice
      neovim
      nixos-shell
      opencode
      openspec
      openssl
      perf
      qbittorrent
      # qemu
      ruff
      shfmt
      steamcmd
      steam-run
      telegram-desktop
      thunderbird
      tor-browser
      tumbler
      unrar
      ydotool

      # niri ecosystem
      fuzzel
      grim
      kdePackages.kio-fuse
      kdePackages.kio-extras
      kitty
      mako
      pavucontrol
      slurp
      swaylock
      swaybg
      thunar
      waybar
      wl-clipboard
    ]
  );
}
