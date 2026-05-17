{ config, pkgs, ... }:
{
  imports = [
    # ./users
    ../common/sudo.nix
  ];
  users.defaultUserShell = pkgs.zsh;
  users.users.antares = {
    isNormalUser = true;
    home = (import ../common/localFileDef.nix { username = "antares"; }).userhome;
    description = "Antares0982";
    extraGroups = [
      "wheel"
    ];
    uid = 1000;
    useDefaultShell = true;
  };
  wsl.defaultUser = "antares";
}
