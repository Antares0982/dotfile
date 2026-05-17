{ config, pkgs, ... }:
{
  imports = [
    ./users
    ../common/sudo.nix
  ];
  users.defaultUserShell = pkgs.zsh;
  # security.sudo = {
  #   wheelNeedsPassword = false;
  #   extraConfig = ''
  #     Defaults env_keep += "http_proxy https_proxy"
  #   '';
  # };
}
