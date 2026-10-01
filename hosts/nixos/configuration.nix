{
  config,
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  services.telegram-output-monitor-bot.enable = true;
  antares.monitor.proxy = if config.antares.proxy.enable then config.antares.proxy.httpUrl else null;
  services.antares-rpc-client.enable = true;
  antares.xray.enable = true;
  antares.proxy.enable = true;
  antares.autostart.enable = true;
  services.rabbitmq.enable = true;
  antares.desktop.enable = true;
  services.pipewire.enable = true;
  hardware.bluetooth.enable = true;
  i18n.inputMethod.enable = true;
  services.samba.enable = true;
  programs.steam.enable = true;
  programs.ydotool.enable = true;
  antares.rust.enable = true;
  services.mcp-nixos.enable = true;
  antares.waitOnline.enable = true;
  antares.githubAuth.enable = true;
  imports = [ ../../pc ];
  _module.args = {
    myXray = inputs.myXray.packages.${system}.default;
    xray-sub = inputs.myXray.packages.${system}.xray_sub;
    antares-rpc-client = inputs.antares-rpc-client.packages.${system}.default;
    pull-all = inputs.pull-all.packages.${system}.default;
    rust-overlay = inputs.rust-overlay.overlays.default;
    linyinfeng-nur-packages = inputs.linyinfeng-nur.packages.${system};
  };
}
