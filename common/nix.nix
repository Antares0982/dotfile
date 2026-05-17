{
  config,
  pkgs,
  lib,
  currentDevice,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [
        "root"
        "antares"
      ];
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    }
    // lib.attrsets.optionalAttrs (currentDevice.mac) {
      interval = [
        {
          Hour = 4;
          Minute = 0;
          Weekday = 7;
        }
      ];
    }
    // lib.attrsets.optionalAttrs (!currentDevice.mac) {
      dates = "weekly";
    };
  };
}
// lib.attrsets.optionalAttrs (currentDevice.useProxy && !currentDevice.mac) {
  systemd.services.nix-daemon.environment = {
    http_proxy = "http://127.0.0.1:1081";
    https_proxy = "http://127.0.0.1:1081";
  };
}
