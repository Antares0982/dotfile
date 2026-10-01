{ lib }: [
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
    name = "desktop-off";
    module = { lib, ... }: { antares.desktop.enable = lib.mkForce false; };
    check =
      c:
      !c.programs.niri.enable
      && !(c.systemd.services ? git-sign-unlock)
      && !(c.home-manager.users.antares.systemd.user.services ? git-sign-unlock)
      && !(c.age.secrets ? gitSignPassphrase)
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
    name = "steam-off";
    module = { lib, ... }: { programs.steam.enable = lib.mkForce false; };
    check =
      c:
      !c.programs.steam.remotePlay.openFirewall
      && !c.programs.steam.dedicatedServer.openFirewall
      && !(lib.any (p: lib.getName p == "steamcmd") c.environment.systemPackages);
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
    name = "github-auth-off";
    module = { lib, ... }: { antares.githubAuth.enable = lib.mkForce false; };
    check =
      c:
      !(c.age.secrets ? ghToken)
      && !(lib.hasInfix "export GH_TOKEN=" c.home-manager.users.antares.programs.zsh.initContent);
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
        githubAuth.enable = lib.mkForce false;
        gitSignUnlock.enable = lib.mkForce false;
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
      && !(c.age.secrets ? ghToken)
      && !(c.age.secrets ? gitSignPassphrase)
      && !(c.systemd.services ? git-sign-unlock)
      && builtins.attrNames c.home-manager.users.antares.systemd.user.services == [ "nix-gc" ];
  }
]
