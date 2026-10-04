{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCommonSettings = import ../common/users.nix {
    inherit (config.age) secrets;
  };
in
{
  users = {
    # mutableUsers = false;
    users.antares = {
      isNormalUser = true;
      home = "/home/antares";
      description = "Antares0982";
      extraGroups = [
        "wheel"
      ];
      uid = 1000;
      useDefaultShell = true;
      hashedPasswordFile = userCommonSettings.serverHashedPasswordFile;
      openssh.authorizedKeys.keys = [ userCommonSettings.superUserAuthorizedKey ];
      linger = true;
    };
  };
  users.defaultUserShell = pkgs.zsh;
  imports = [ ../common/sudo.nix ];
}
