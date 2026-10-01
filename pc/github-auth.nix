{ config, lib, ... }:
{
  options.antares.githubAuth.enable = lib.mkEnableOption "GitHub shell credentials";
  config = lib.mkIf config.antares.githubAuth.enable {
    age.secrets.ghToken = {
      file = ../secrets/gh-token.age;
      owner = "antares";
      group = "users";
      mode = "400";
    };
  };
}
