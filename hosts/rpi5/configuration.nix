{ config, pkgs-new, ... }: {
  services.antares-runners.instances.actionrunner = {
    enable = true;
    user = "actionrunner";
    serviceName = "github-runner";
    package = pkgs-new.github-runner;
    proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
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
    proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
    ];
  };
  services.antares-runners.instances.nixdev = {
    enable = true;
    user = "ssrjsonnixdev";
    serviceName = "ssrjson-nixdev-runner";
    package = pkgs-new.github-runner;
    proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDOMS7+EqU5j6TmQrQyg/9TG4oPfnR1J13B6jvmnqdI0 antares@alyr.dev"
    ];
  };
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
  services.antares-rpc-client.enable = true;
  antares.agent.enable = true;
  antares.qq.napcat.enable = true;
  antares.qq.relay.enable = true;
  antares.qq.enable = true;
  antares.qq.codex.enable = true;
  antares.xray.enable = true;
  antares.proxy.enable = true;
  services.rabbitmq.enable = true;
  services.ssh-probe.enable = true;
  antares.gitServer.enable = true;
  imports = [ ../../rpi ];
  environment.etc."zsh/p10k.zsh".source = ../../resource/rpi-p10k.zsh;
}
