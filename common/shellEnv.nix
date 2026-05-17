{
  sysBin = "/run/current-system/sw/bin";
  aliases = {
    top = "top -d 0.33";
    make = "make -j$(nproc)";
    ctl = "systemctl --user";
    eza = "eza --icons=always --hyperlink --color=always --color-scale=all --color-scale-mode=gradient --git --git-repos";
    ls = "eza";
  };
}
