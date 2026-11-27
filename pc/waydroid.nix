{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.virtualisation.waydroid.enable {
    virtualisation.waydroid.package = pkgs.waydroid-nftables;
    security.polkit.enablePkexecWrapper = true;
    environment.systemPackages = [
      pkgs.jadx
      pkgs.waydroid-helper
    ];
  };
}
