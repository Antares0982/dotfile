{ lib }: [
  {
    name = "base";
    module = { };
    check =
      c:
      c.networking.hostName == "gz"
      && c.users.mutableUsers == false
      && c.users.users.antares.uid == 1000
      && c.users.users.antares.home == "/home/antares"
      && c.users.users.antares.extraGroups == [ "wheel" ]
      && c.users.users.antares.linger
      && c.users.defaultUserShell == c.users.users.antares.shell
      &&
        c.users.users.antares.openssh.authorizedKeys.keys == [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS4Ty97Xiann8mMJHDjv5HqCzdideBuPq28PeVSHvZH antares@gz"
        ]
      && c.services.openssh.enable
      && c.services.openssh.settings.PermitRootLogin == "no"
      && c.services.openssh.settings.PasswordAuthentication == false
      && c.services.openssh.settings.KbdInteractiveAuthentication == false
      && c.users.users.root.openssh.authorizedKeys.keys == [ ]
      && !c.security.sudo.wheelNeedsPassword
      &&
        builtins.attrNames c.age.secrets == [
          "l4d2-private"
          "l4d2-rcon"
          "serverPassword"
          "xraySubUrl"
          "xrayTemplateJson"
        ]
      && c.age.identityPaths == [ "/etc/ssh/agenix" ]
      && c.users.users.antares.hashedPasswordFile == c.age.secrets.serverPassword.path
      && !(c.users.users ? alice)
      && !(c.users.users ? git)
      && c.boot.loader.grub.devices == [ "/dev/vda" ]
      && c.disko.devices.disk.main.device == "/dev/vda"
      && c.fileSystems."/".fsType == "ext4"
      && c.networking.interfaces.eth0.useDHCP
      && c.services.fail2ban.enable
      && c.services.sysstat.enable
      && c.services.sysstat.collect-frequency == "*:00/01"
      && c.services.sysstat.collect-args == "1 1"
      && c.networking.firewall.enable
      && c.networking.firewall.allowedTCPPorts == [ 22 ]
      && c.networking.firewall.allowedUDPPorts == [ 27015 ]
      && c.networking.firewall.allowedTCPPortRanges == [ ]
      && c.services.xray.enable
      && c.services.xray.settingsFile == "/var/xray/config.json"
      && c.systemd.services.xray.serviceConfig.DynamicUser
      && c.systemd.services.xray.serviceConfig.LoadCredential == "config.json:/var/xray/config.json"
      && c.systemd.services.xray.unitConfig.ConditionPathExists == "/var/xray/config.json"
      && c.systemd.services.xray-sub.serviceConfig.User == "antares"
      && lib.hasInfix "/run/wrappers/bin" c.systemd.services.xray-sub.environment.PATH
      && c.systemd.timers.xray-sub.timerConfig.OnCalendar == "daily"
      && c.systemd.timers.xray-sub.timerConfig.Persistent
      && c.age.secrets.xraySubUrl.owner == "antares"
      && c.age.secrets.xraySubUrl.mode == "0400"
      && c.age.secrets.xrayTemplateJson.mode == "0400"
      && lib.hasSuffix "/xraysub.age" (toString c.age.secrets.xraySubUrl.file)
      && lib.hasSuffix "/xray-template-gz.age" (toString c.age.secrets.xrayTemplateJson.file)
      && lib.any (p: lib.getName p == "xs") c.environment.systemPackages
      && c.environment.variables.http_proxy == "http://127.0.0.1:1081"
      && c.environment.variables.HTTPS_PROXY == c.environment.variables.http_proxy
      && c.environment.variables.ALL_PROXY == "socks5h://127.0.0.1:1080"
      && c.environment.variables.NO_PROXY == "localhost,127.0.0.1,::1"
      && c.systemd.services.nix-daemon.environment.http_proxy == c.environment.variables.http_proxy
      && c.systemd.services.nix-daemon.environment.ALL_PROXY == c.environment.variables.ALL_PROXY;
  }
  {
    name = "proxy-off";
    module = { lib, ... }: { antares.proxy.enable = lib.mkForce false; };
    check =
      c:
      c.services.xray.enable
      && !(c.environment.variables ? http_proxy)
      && !(c.environment.variables ? ALL_PROXY)
      && !(c.systemd.services.nix-daemon.environment ? http_proxy)
      && !(c.systemd.services.nix-daemon.environment ? ALL_PROXY);
  }
  {
    name = "xray-off";
    module = { lib, ... }: {
      services.xray.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.systemd.services ? xray)
      && !(c.systemd.services ? xray-sub)
      && !(c.systemd.timers ? xray-sub)
      &&
        builtins.attrNames c.age.secrets == [
          "l4d2-private"
          "l4d2-rcon"
          "serverPassword"
        ]
      && !(lib.any (p: lib.getName p == "xs") c.environment.systemPackages)
      && !(c.environment.variables ? http_proxy)
      && !(c.systemd.services.nix-daemon.environment ? http_proxy)
      && c.users.users ? antares;
  }
  {
    name = "l4d2";
    module = { };
    check =
      c:
      c.antares.l4d2.enable
      && c.users.users.l4d2.home == "/home/l4d2"
      && c.users.users.l4d2.hashedPassword == "!"
      && c.users.users.l4d2.extraGroups == [ ]
      && builtins.length c.users.users.l4d2.openssh.authorizedKeys.keys == 1
      && c.age.secrets.l4d2-rcon.owner == "l4d2"
      && c.age.secrets.l4d2-rcon.mode == "0400"
      && c.age.secrets.l4d2-private.owner == "l4d2"
      && c.age.secrets.l4d2-private.mode == "0400"
      && c.systemd.services.l4d2.serviceConfig.User == "l4d2"
      && lib.hasInfix "-nomaster" c.systemd.services.l4d2.serviceConfig.ExecStart
      && c.systemd.timers.l4d2-update.timerConfig.OnCalendar == "*-*-* 05:00:00 Asia/Shanghai"
      && !c.systemd.timers.l4d2-update.timerConfig.Persistent
      && c.networking.firewall.allowedTCPPorts == [ 22 ];
  }
  {
    name = "l4d2-off";
    module = { lib, ... }: { antares.l4d2.enable = lib.mkForce false; };
    check =
      c:
      !(c.users.users ? l4d2)
      && !(c.users.groups ? l4d2)
      && !(c.age.secrets ? l4d2-rcon)
      && !(c.age.secrets ? l4d2-private)
      && !(c.systemd.services ? l4d2)
      && !(c.systemd.services ? l4d2-install)
      && !(c.systemd.services ? l4d2-update)
      && !(c.systemd.timers ? l4d2-update)
      && c.networking.firewall.allowedUDPPorts == [ ]
      && c.users.users ? antares;
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { services.xray.enable = lib.mkForce false; };
    valid = false;
    check = c: !(c.systemd.services ? xray) && c.antares.proxy.enable;
  }
]
