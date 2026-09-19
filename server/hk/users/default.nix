{
  config,
  pkgs,
  myXray,
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

    acme = {
      extraGroups = [ "nginx" ];
    };
  };
  # home manager
  home-manager = {
    useGlobalPkgs = true;
    users = {
      alice = import ./alice;
    };
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit myXray antares-rpc-client; };
  };
}
