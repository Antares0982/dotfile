{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  runnerPackage =
    (import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    }).github-runner;
in
{
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#8700d7";
  };
  services.antares-runners.instances.actionrunner = {
    enable = true;
    user = "actionrunner";
    serviceName = "github-runner";
    package = runnerPackage;
    proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
    authorizedKeys = [
      (import ../../common/users.nix { inherit (config.age) secrets; }).commonUserAuthorizedKey
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
  antares.mihomo = {
    enable = true;
    lan = true;
    dashboardOrigins = [ "http://192.168.0.3:17900" ];
  };
  antares.proxy.enable = true;
  antares.proxy.socksUrl = "socks5h://127.0.0.1:1081";
  services.rabbitmq.enable = true;
  services.ssh-probe.enable = true;
  antares.gitServer.enable = true;
  imports = [ ../../rpi ];
  environment.variables.NIX_DOT_FILES = "/home/antares/Nix";
  programs.zsh.shellInit = ''
    export PATH=$PATH:$HOME/scripts:$HOME/scripts/linux
  '';
  _module.args = {
    antares-rpc-client = inputs.antares-rpc-client.packages.${system}.default;
    napcat = inputs.napcat-nix.packages.${system}.default;
  };
}
