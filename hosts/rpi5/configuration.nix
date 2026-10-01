{ config, pkgs-new, ... }: {
  services.antares-runners.instances.actionrunner = {
    enable = true;
    user = "actionrunner";
    serviceName = "github-runner";
    package = pkgs-new.github-runner;
    proxy = "http://127.0.0.1:1081";
    authorizedKeys = [
      (import ../../common/users.nix { inherit (config.age) secrets; }).commonUserAuthorizedKey
    ];
  };
}
