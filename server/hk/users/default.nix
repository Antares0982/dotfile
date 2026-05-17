{
  config,
  pkgs,
  myXray,
  antares-monitor,
  antares-rpc-client,
  ...
}:
let
  userCommonSettings = import ../../../common/users.nix {
    inherit (config.age) secrets;
  };
in
{
  users.users = {
    alice = {
      isNormalUser = true;
      home = "/home/alice";
      description = "maid alice";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        userCommonSettings.commonUserAuthorizedKey
      ];
      inherit (userCommonSettings) hashedPasswordFile;
      linger = true;
    };
    openai = {
      isNormalUser = true;
      home = "/home/openai";
      description = "openai session keeper";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        userCommonSettings.commonUserAuthorizedKey
      ];
      inherit (userCommonSettings) hashedPasswordFile;
      linger = true;
    };
    acme = {
      extraGroups = [ "nginx" ];
    };
  };
  # home manager
  home-manager.useGlobalPkgs = true;
  home-manager.users = {
    alice = import ./alice;
    openai = import ./openai;
  };
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = {
    inherit myXray antares-monitor antares-rpc-client;
  };
}
