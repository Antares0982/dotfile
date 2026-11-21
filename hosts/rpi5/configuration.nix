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
  antares.proxy = {
    enable = true;
    insideGFW = true;
    lan = true;
  };
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#8700d7";
  };
  services.antares-runners.instances.actionrunner = {
    enable = true;
    user = "actionrunner";
    serviceName = "github-runner";
    package = runnerPackage;
    proxy = if config.antares.proxy.exportEnvironment then config.antares.proxy.httpUrl else null;
    authorizedKeys = [
      (import ../../common/users.nix { inherit (config.age) secrets; }).commonUserAuthorizedKey
    ];
  };
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy =
    if config.antares.proxy.exportEnvironment then config.antares.proxy.httpUrl else null;
  services.antares-rpc-client.enable = true;
  antares.agent.enable = true;
  antares.qq.napcat.enable = true;
  antares.qq.relay.enable = true;
  antares.qq.enable = true;
  antares.qq.codex.enable = true;
  antares.mihomo.dashboardOrigins = [ "http://192.168.0.3:17900" ];
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
