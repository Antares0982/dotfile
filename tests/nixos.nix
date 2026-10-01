{ lib }: [
  {
    name = "monitor-off";
    module = { lib, ... }: { services.telegram-output-monitor-bot.enable = lib.mkForce false; };
    check =
      c: !(c.systemd.services ? telegram-output-monitor-bot) && !(c.age.secrets ? monitorCfgAntaresPc);
  }
  {
    name = "rpc-off";
    module = { lib, ... }: { services.antares-rpc-client.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.antares.systemd.user.services ? rpc-client)
      && !(c.age.secrets ? rabbitClientCfgAntaresPc)
      && c.users.users ? antares;
  }
  {
    name = "xray-off";
    module = { lib, ... }: {
      antares.xray.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
      antares.autostart.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.home-manager.users.antares.systemd.user.services ? xray)
      && !(c.home-manager.users.antares.systemd.user.services ? autostart)
      && !(c.home-manager.users.antares.home.sessionVariables ? http_proxy)
      && !(c.systemd.services.nix-daemon.environment ? http_proxy)
      && !(lib.any (p: p.from == 1080) c.networking.firewall.allowedTCPPortRanges);
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { antares.xray.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "rabbitmq-off";
    module = { lib, ... }: { services.rabbitmq.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? rabbitmq) && !(c.users.users ? rabbitmq);
  }
  {
    name = "desktop-off";
    module = { lib, ... }: { antares.desktop.enable = lib.mkForce false; };
    check =
      c:
      !c.programs.niri.enable
      && !c.services.greetd.enable
      && !c.programs.kdeconnect.enable
      && !c.home-manager.users.antares.xdg.mimeApps.enable
      && !(c.environment.sessionVariables ? NIXOS_OZONE_WL)
      && !(lib.any (p: p.from == 1714) c.networking.firewall.allowedTCPPortRanges)
      && c.users.users ? antares;
  }
  {
    name = "audio-off";
    module = { lib, ... }: { services.pipewire.enable = lib.mkForce false; };
    check =
      c: !c.security.rtkit.enable && !(c.systemd.services ? rtkit-daemon) && !c.services.pipewire.enable;
  }
  {
    name = "bluetooth-off";
    module = { lib, ... }: { hardware.bluetooth.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? bluetooth) && !c.hardware.bluetooth.enable;
  }
  {
    name = "input-off";
    module = { lib, ... }: { i18n.inputMethod.enable = lib.mkForce false; };
    check =
      c:
      !c.i18n.inputMethod.enable
      && !(lib.any (p: lib.hasPrefix "fcitx5" (lib.getName p)) c.environment.systemPackages);
  }
]
