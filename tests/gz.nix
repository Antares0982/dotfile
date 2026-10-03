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
      && c.networking.firewall.allowedUDPPorts == [ ]
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
      && builtins.attrNames c.age.secrets == [ "serverPassword" ]
      && !(lib.any (p: lib.getName p == "xs") c.environment.systemPackages)
      && !(c.environment.variables ? http_proxy)
      && !(c.systemd.services.nix-daemon.environment ? http_proxy)
      && c.users.users ? antares;
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { services.xray.enable = lib.mkForce false; };
    valid = false;
    check = c: !(c.systemd.services ? xray) && c.antares.proxy.enable;
  }
]
