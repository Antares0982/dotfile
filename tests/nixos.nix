{ lib }: [
  {
    name = "gpu-unlock-on";
    module = { };
    check =
      c:
      c.antares.gpuUnlock.enable
      && lib.elem "gpu_unlock.targets=0000:01:00.0" c.boot.kernelParams
      && lib.elem "gpu_unlock" c.boot.initrd.availableKernelModules
      && lib.any (p: lib.getName p == "gpu-unlock") c.boot.extraModulePackages
      && lib.any (p: lib.getName p == "gpu-unlock-firmware") c.hardware.firmware.paths
      && c.boot.initrd.systemd.services.gpu-unlock.wantedBy == [ "sysinit.target" ]
      && !c.boot.initrd.systemd.services.gpu-unlock.unitConfig.DefaultDependencies
      && lib.all (unit: lib.elem unit c.boot.initrd.systemd.services.gpu-unlock.before) [
        "systemd-modules-load.service"
        "systemd-udev-trigger.service"
        "systemd-udevd.service"
      ];
  }
  {
    name = "gpu-unlock-off";
    module = { lib, ... }: { antares.gpuUnlock.enable = lib.mkForce false; };
    check =
      c:
      !(lib.any (lib.hasPrefix "gpu_unlock.") c.boot.kernelParams)
      && !(lib.elem "gpu_unlock" c.boot.initrd.availableKernelModules)
      && !(lib.any (p: lib.getName p == "gpu-unlock") c.boot.extraModulePackages)
      && !(lib.any (p: lib.getName p == "gpu-unlock-firmware") c.hardware.firmware.paths)
      && !(c.boot.initrd.systemd.services ? gpu-unlock);
  }
  {
    name = "openlist-on";
    module = { };
    check =
      c:
      c.systemd.services.openlist.environment.OPENLIST_ADDR == "127.0.0.1"
      && c.systemd.services.openlist.serviceConfig.StateDirectoryMode == "0700"
      && c.systemd.services.openlist.serviceConfig.DynamicUser
      && !(lib.elem 5244 c.networking.firewall.allowedTCPPorts);
  }
  {
    name = "openlist-off";
    module = { lib, ... }: { services.openlist.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? openlist);
  }
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
    name = "wallpaper-on";
    module = { };
    check =
      c:
      let
        home = c.home-manager.users.antares;
        service = home.systemd.user.services.we-layerd;
        timer = home.systemd.user.timers.we-layerd-switch;
      in
      service.Unit.PartOf == [ "niri.service" ]
      && service.Install.WantedBy == [ "niri.service" ]
      && service.Service.Restart == "on-failure"
      && lib.any (package: lib.getName package == "we-wallpaper") home.home.packages
      && timer.Timer.OnCalendar == "*-*-* 00,06,19:00:00"
      && timer.Timer.Persistent
      && timer.Timer.OnClockChange
      && timer.Timer.OnTimezoneChange
      && home.xdg.configFile ? "we-layerd/config.toml"
      && home.xdg.configFile ? "we-layerd/evening.toml"
      && home.xdg.configFile ? "we-layerd/night.toml"
      && c.environment.etc ? "greetd/we-layerd.toml"
      && lib.elem "d /var/lib/we-layerd/current 0755 root root -" c.systemd.tmpfiles.rules
      && lib.all (rule: lib.elem rule c.systemd.tmpfiles.rules) [
        "L /var/lib/we-layerd/current/day-main - - - - /var/lib/we-layerd/workshop/3759473977"
        "L /var/lib/we-layerd/current/day-secondary - - - - /var/lib/we-layerd/workshop/3657215414"
        "L /var/lib/we-layerd/current/evening-main - - - - /var/lib/we-layerd/workshop/3545541611"
        "L /var/lib/we-layerd/current/evening-secondary - - - - /var/lib/we-layerd/workshop/3780257889"
        "L /var/lib/we-layerd/current/night-main - - - - /var/lib/we-layerd/workshop/3222456142"
        "L /var/lib/we-layerd/current/night-secondary - - - - /var/lib/we-layerd/workshop/3780257889"
        "L /var/lib/we-layerd/current/greeter - - - - /var/lib/we-layerd/workshop/3482954869"
      ]
      && lib.hasInfix "/bin/niri --config" c.services.greetd.settings.default_session.command
      && !(lib.hasInfix "/home/antares" c.services.greetd.settings.default_session.command);
  }
  {
    name = "wallpaper-off";
    module = { lib, ... }: { antares.wallpaper.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.antares.systemd.user.services ? we-layerd)
      && !(lib.any (
        package: lib.getName package == "we-wallpaper"
      ) c.home-manager.users.antares.home.packages)
      && !(c.home-manager.users.antares.systemd.user.timers ? we-layerd-switch)
      && !(c.home-manager.users.antares.xdg.configFile ? "we-layerd/config.toml")
      && !(c.environment.etc ? "greetd/we-layerd.toml")
      && !(lib.any (lib.hasInfix "/var/lib/we-layerd") c.systemd.tmpfiles.rules)
      && lib.hasInfix "/bin/cage" c.services.greetd.settings.default_session.command
      && lib.hasInfix "/boot/background.png" c.services.displayManager.regreet.extraCss;
  }
  {
    name = "video-defaults";
    module = { };
    check =
      c:
      lib.all
        (
          mime:
          c.home-manager.users.antares.xdg.mimeApps.defaultApplications.${mime}
          == [ "org.kde.haruna.desktop" ]
        )
        [
          "video/matroska"
          "video/x-matroska"
          "video/mp4"
          "video/webm"
        ];
  }
  {
    name = "niri-session";
    module = { };
    check =
      c:
      let
        home = c.home-manager.users.antares;
        services = home.systemd.user.services;
      in
      home.xdg.configFile ? "niri/config.kdl"
      && home.programs.waybar.systemd.enable
      && home.systemd.user.startServices
      &&
        lib.all
          (
            name:
            lib.elem "graphical-session.target" services.${name}.Unit.PartOf
            && lib.elem "graphical-session.target" services.${name}.Install.WantedBy
            && services.${name}.Service.Restart == "on-failure"
          )
          [
            "waybar"
            "mako"
            "kdeconnect-indicator"
            "lxqt-policykit-agent"
            "qbittorrent"
          ]
      && lib.elem "waybar.service" services.qbittorrent.Unit.After
      && !(lib.elem "waybar.service" services.qbittorrent.Unit.PartOf)
      && services.qbittorrent.Service.TimeoutStopSec == 120;
  }
  {
    name = "desktop-off";
    module = { lib, ... }: { antares.desktop.enable = lib.mkForce false; };
    check =
      c:
      !c.programs.niri.enable
      && !(c.home-manager.users.antares.xdg.configFile ? "niri/config.kdl")
      && lib.all (name: !(builtins.hasAttr name c.home-manager.users.antares.systemd.user.services)) [
        "waybar"
        "mako"
        "kdeconnect-indicator"
        "lxqt-policykit-agent"
        "qbittorrent"
      ]
      && !(c.home-manager.users.antares.systemd.user.services ? we-layerd)
      && !(c.home-manager.users.antares.systemd.user.timers ? we-layerd-switch)
      && !(c.home-manager.users.antares.xdg.configFile ? "we-layerd/config.toml")
      && !(c.environment.etc ? "greetd/we-layerd.toml")
      && !(lib.any (lib.hasInfix "/var/lib/we-layerd") c.systemd.tmpfiles.rules)
      && !(c.systemd.services ? git-sign-unlock)
      && !(c.home-manager.users.antares.systemd.user.services ? git-sign-unlock)
      && !(c.age.secrets ? gitSignPassphrase)
      && !c.services.greetd.enable
      && !c.programs.kdeconnect.enable
      && !c.home-manager.users.antares.xdg.mimeApps.enable
      && !(c.home-manager.users.antares.xdg.configFile ? "kitty/kitty.conf")
      && !(c.home-manager.users.antares.xdg.configFile ? "kitty/fcitx5.py")
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
    name = "kitty-input-on";
    module = { };
    check =
      c:
      c.home-manager.users.antares.xdg.configFile ? "kitty/fcitx5.py"
      &&
        lib.hasInfix "watcher fcitx5.py"
          c.home-manager.users.antares.xdg.configFile."kitty/kitty.conf".text;
  }
  {
    name = "input-off";
    module = { lib, ... }: { i18n.inputMethod.enable = lib.mkForce false; };
    check =
      c:
      !c.i18n.inputMethod.enable
      && !(c.home-manager.users.antares.xdg.configFile ? "kitty/fcitx5.py")
      && !(lib.hasInfix "watcher" c.home-manager.users.antares.xdg.configFile."kitty/kitty.conf".text)
      && !(lib.any (p: lib.hasPrefix "fcitx5" (lib.getName p)) c.environment.systemPackages);
  }
  {
    name = "samba-off";
    module = { lib, ... }: { services.samba.enable = lib.mkForce false; };
    check =
      c:
      !c.services.samba.openFirewall
      && !(lib.elem 445 c.networking.firewall.allowedTCPPorts)
      && !(c.systemd.services ? samba-smbd);
  }
  {
    name = "steam-on";
    module = { };
    check =
      c:
      c.age.secrets.steamApiKey.owner == "antares"
      && c.age.secrets.steamApiKey.group == "users"
      && c.age.secrets.steamApiKey.mode == "0400"
      && lib.any (p: lib.getName p == "steam-workshop-ts") c.environment.systemPackages;
  }
  {
    name = "steam-off";
    module = { lib, ... }: { programs.steam.enable = lib.mkForce false; };
    check =
      c:
      !c.programs.steam.remotePlay.openFirewall
      && !c.programs.steam.dedicatedServer.openFirewall
      && !(c.age.secrets ? steamApiKey)
      && !(lib.any (
        p:
        lib.elem (lib.getName p) [
          "steamcmd"
          "steam-workshop-ts"
        ]
      ) c.environment.systemPackages);
  }
  {
    name = "ydotool-off";
    module = { lib, ... }: { programs.ydotool.enable = lib.mkForce false; };
    check =
      c:
      !(lib.elem "ydotool" c.users.users.antares.extraGroups)
      && !(lib.any (p: lib.getName p == "ydotool") c.environment.systemPackages)
      && !(c.systemd.services ? ydotoold)
      && c.users.users ? antares;
  }
  {
    name = "rust-off";
    module = { lib, ... }: { antares.rust.enable = lib.mkForce false; };
    check =
      c:
      c.nixpkgs.overlays == [ ]
      && !(lib.any (p: lib.hasPrefix "rust-" (lib.getName p)) c.environment.systemPackages);
  }
  {
    name = "mcp-off";
    module = { lib, ... }: { services.mcp-nixos.enable = lib.mkForce false; };
    check = c: !(c.systemd.services ? mcp-nixos);
  }
  {
    name = "wait-online-off";
    module = { lib, ... }: { antares.waitOnline.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.antares.systemd.user.services ? waitOnline)
      && !(c.home-manager.users.antares.systemd.user.services ? waitOnlineOnresume);
  }
  {
    name = "autostart-off";
    module = { lib, ... }: { antares.autostart.enable = lib.mkForce false; };
    check =
      c:
      !(c.home-manager.users.antares.systemd.user.services ? autostart)
      && c.home-manager.users.antares.systemd.user.services ? xray;
  }
  {
    name = "git-sign-unlock-on";
    module = { };
    check =
      c:
      let
        secret = c.age.secrets.gitSignPassphrase;
        service = c.systemd.services.git-sign-unlock;
        trigger = c.home-manager.users.antares.systemd.user.services.git-sign-unlock;
      in
      secret.owner == "root"
      && secret.group == "root"
      && secret.mode == "0400"
      && service.serviceConfig.User == "root"
      && service.environment.SSH_AUTH_SOCK == "/run/user/${toString c.users.users.antares.uid}/ssh-agent"
      && service.environment.SSH_ASKPASS_REQUIRE == "force"
      && service.wantedBy == [ ]
      &&
        trigger.Unit.After == [
          "niri.service"
          "ssh-agent.service"
        ]
      && trigger.Unit.Requires == [ "ssh-agent.service" ]
      && trigger.Unit.PartOf == [ "niri.service" ]
      && trigger.Install.WantedBy == [ "niri.service" ];
  }
  {
    name = "git-sign-unlock-off";
    module = { lib, ... }: { antares.gitSignUnlock.enable = lib.mkForce false; };
    check =
      c:
      !(c.systemd.services ? git-sign-unlock)
      && !(c.home-manager.users.antares.systemd.user.services ? git-sign-unlock)
      && !(c.age.secrets ? gitSignPassphrase)
      && c.programs.ssh.startAgent;
  }
  {
    name = "git-sign-unlock-dependency";
    module = { lib, ... }: { programs.ssh.startAgent = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "yazi-on";
    module = { };
    check =
      c:
      let
        home = c.home-manager.users.antares;
        rule = builtins.head home.programs.yazi.settings.open.prepend_rules;
      in
      home.xdg.configFile ? "yazi/yazi.toml"
      && rule.url == "*.{blend,blender}"
      &&
        rule.use == [
          "open"
          "reveal"
        ];
  }
  {
    name = "yazi-off";
    module = { lib, ... }: { home-manager.users.antares.programs.yazi.enable = lib.mkForce false; };
    check =
      c:
      let
        home = c.home-manager.users.antares;
      in
      !(lib.any (p: lib.getName p == "yazi") home.home.packages)
      && !(lib.any (name: lib.hasPrefix "yazi/" name) (builtins.attrNames home.xdg.configFile))
      && !(lib.hasInfix "command yazi" home.programs.zsh.initContent);
  }
  {
    name = "all-features-off";
    module = { lib, ... }: {
      antares = {
        desktop.enable = lib.mkForce false;
        xray.enable = lib.mkForce false;
        proxy.enable = lib.mkForce false;
        autostart.enable = lib.mkForce false;
        waitOnline.enable = lib.mkForce false;
        gitSignUnlock.enable = lib.mkForce false;
        gpuUnlock.enable = lib.mkForce false;
        rust.enable = lib.mkForce false;
      };
      services.pipewire.enable = lib.mkForce false;
      hardware.bluetooth.enable = lib.mkForce false;
      i18n.inputMethod.enable = lib.mkForce false;
      services.samba.enable = lib.mkForce false;
      programs.steam.enable = lib.mkForce false;
      programs.ydotool.enable = lib.mkForce false;
      services.mcp-nixos.enable = lib.mkForce false;
      services.openlist.enable = lib.mkForce false;
      services.telegram-output-monitor-bot.enable = lib.mkForce false;
      services.antares-rpc-client.enable = lib.mkForce false;
      services.rabbitmq.enable = lib.mkForce false;
      home-manager.users.antares.programs.yazi.enable = lib.mkForce false;
    };
    check =
      c:
      c.users.users ? antares
      && !(c.systemd.services ? openlist)
      && !(c.age.secrets ? gitSignPassphrase)
      && !(c.systemd.services ? git-sign-unlock)
      && builtins.attrNames c.home-manager.users.antares.systemd.user.services == [ "nix-gc" ];
  }
]
