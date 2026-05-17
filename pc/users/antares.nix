{
  config,
  pkgs,
  myXray,
  antares-monitor,
  antares-rpc-client,
  pull-all,
  xray-sub,
  ...
}:
{
  # imports = [ <home-manager/nixos> ];
  users.users.antares = {
    isNormalUser = true;
    home = (import ../../common/localFileDef.nix { username = "antares"; }).userhome;
    description = "Antares0982";
    extraGroups = [
      "wheel"
      "ydotool"
    ]
    ++ pkgs.lib.optionals config.virtualisation.docker.enable [
      "docker"
    ];
    uid = 1000;
    useDefaultShell = true;
  };
  home-manager.useGlobalPkgs = true;
  home-manager.users.antares = import ./antares-home;
  home-manager.extraSpecialArgs = {
    inherit
      myXray
      antares-monitor
      antares-rpc-client
      pull-all
      xray-sub
      ;
  };
}
