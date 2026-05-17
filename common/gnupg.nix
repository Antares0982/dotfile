{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.gnupg.agent = {
    enable = true;
    settings = {
      default-cache-ttl = 3600;
      max-cache-ttl = 86400;
    };
  };
}
