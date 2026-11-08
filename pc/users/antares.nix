{
  config,
  pkgs,
  antares-rpc-client,
  pull-all,
  ...
}:
{
  users.users.antares = {
    isNormalUser = true;
    home = (import ../../common/localFileDef.nix { username = "antares"; }).userhome;
    description = "Antares0982";
    extraGroups = [
      "wheel"
    ];
    uid = 1000;
    useDefaultShell = true;
  };
  home-manager = {
    useGlobalPkgs = true;
    users.antares = import ./antares-home;
    extraSpecialArgs = {
      inherit
        antares-rpc-client
        pull-all
        ;
    };
  };
}
