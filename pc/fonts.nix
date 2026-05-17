{
  config,
  pkgs,
  linyinfeng-nur-packages,
  ...
}:
{
  fonts = {
    enableDefaultPackages = true;
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages =
      with pkgs;
      [
        cascadia-code
        fira-code
        meslo-lgs-nf
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        sarasa-gothic
        source-han-serif
        wqy_microhei
        wqy_zenhei
        linyinfeng-nur-packages.plangothic
      ]
      ++ (with pkgs.nerd-fonts; [
        fira-code
        inconsolata
      ]);
  };
}
