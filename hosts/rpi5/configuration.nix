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
  services.antares-runners.instances.ssrjson = {
    enable = true;
    user = "ssrjsonrunner";
    serviceName = "ssrjson-runner";
    count = 10;
    indexed = true;
    package = pkgs-new.github-runner;
    proxy = "http://127.0.0.1:1081";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
    ];
  };
  services.antares-runners.instances.nixdev = {
    enable = true;
    user = "ssrjsonnixdev";
    serviceName = "ssrjson-nixdev-runner";
    package = pkgs-new.github-runner;
    proxy = "http://127.0.0.1:1081";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
    ];
  };
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy = "http://127.0.0.1:1081";
  services.antares-rpc-client.enable = true;
  antares.agent.enable = true;
  antares.qq.napcat.enable = true;
  antares.qq.relay.enable = true;
  antares.qq.enable = true;
  antares.qq.codex.enable = true;
}
