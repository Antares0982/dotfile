{
  lib,
  host ? "gz",
}:
[
  {
    name = "base";
    module = { };
    check =
      c:
      c.networking.hostName == host
      && c.users.mutableUsers == false
      && c.users.users.antares.uid == 1000
      && c.users.users.antares.home == "/home/antares"
      && c.users.users.antares.extraGroups == [ "wheel" ]
      && c.users.users.antares.linger
      && c.users.defaultUserShell == c.users.users.antares.shell
      &&
        c.users.users.antares.openssh.authorizedKeys.keys == [
          (
            if host == "gz" then
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS4Ty97Xiann8mMJHDjv5HqCzdideBuPq28PeVSHvZH antares@gz"
            else
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3DEDDiBMHxE1V/aXD81+cBY8uRnoT6V8wrY1/DHFvj antares@sz"
          )
        ]
      && c.services.openssh.enable
      && c.services.openssh.settings.PermitRootLogin == "no"
      && c.services.openssh.settings.PasswordAuthentication == false
      && c.services.openssh.settings.KbdInteractiveAuthentication == false
      && c.users.users.root.openssh.authorizedKeys.keys == [ ]
      && !c.security.sudo.wheelNeedsPassword
      &&
        builtins.attrNames c.age.secrets == [
          "cloudflareEnv"
          "l4d2-admins"
          "l4d2-files-htpasswd"
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
      && (
        if host == "gz" then
          c.boot.loader.grub.devices == [ "/dev/vda" ]
        else
          c.boot.loader.grub.efiSupport
          && c.boot.loader.grub.efiInstallAsRemovable
          && !c.boot.loader.efi.canTouchEfiVariables
          && c.fileSystems."/boot".fsType == "vfat"
      )
      && c.disko.devices.disk.main.device == "/dev/vda"
      && c.fileSystems."/".fsType == "ext4"
      && c.networking.interfaces.eth0.useDHCP
      && c.services.fail2ban.enable
      && c.services.sysstat.enable
      && c.services.sysstat.collect-frequency == "*:00/01"
      && c.services.sysstat.collect-args == "1 1"
      && c.networking.firewall.enable
      &&
        lib.sort builtins.lessThan c.networking.firewall.allowedTCPPorts == [
          22
          8443
          27015
        ]
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
          "cloudflareEnv"
          "l4d2-admins"
          "l4d2-files-htpasswd"
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
      && c.antares.l4d2.serverName == (if host == "gz" then "Antares GZ L4D2" else "Antares SZ L4D2")
      && c.users.users.l4d2.openssh.authorizedKeys.keys == c.antares.l4d2.authorizedKeys
      && c.users.users.l4d2.home == "/home/l4d2"
      && c.users.users.l4d2.hashedPassword == "!"
      && c.users.users.l4d2.extraGroups == [ ]
      && builtins.length c.users.users.l4d2.openssh.authorizedKeys.keys == 1
      && c.age.secrets.l4d2-rcon.owner == "l4d2"
      && c.age.secrets.l4d2-rcon.mode == "0400"
      && c.age.secrets.l4d2-private.owner == "l4d2"
      && c.age.secrets.l4d2-private.mode == "0400"
      && c.age.secrets.l4d2-admins.owner == "l4d2"
      && c.age.secrets.l4d2-admins.group == "l4d2"
      && c.age.secrets.l4d2-admins.mode == "0400"
      && lib.hasSuffix "/l4d2-admins.age" (toString c.age.secrets.l4d2-admins.file)
      && builtins.elem c.age.secrets.l4d2-admins.file c.systemd.services.l4d2.restartTriggers
      && c.systemd.services.l4d2.serviceConfig.User == "l4d2"
      && lib.hasInfix "-nomaster" c.systemd.services.l4d2.serviceConfig.ExecStart
      && c.systemd.timers.l4d2-update.timerConfig.OnCalendar == "*-*-* 05:00:00 Asia/Shanghai"
      && !c.systemd.timers.l4d2-update.timerConfig.Persistent
      &&
        lib.sort builtins.lessThan c.networking.firewall.allowedTCPPorts == [
          22
          8443
          27015
        ];
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
      && !(c.age.secrets ? l4d2-admins)
      && !(c.age.secrets ? l4d2-files-htpasswd)
      && !(c.age.secrets ? cloudflareEnv)
      && !(c.systemd.services ? nginx)
      && c.security.acme.certs == { }
      && c.networking.firewall.allowedTCPPorts == [ 22 ]
      && !(c.systemd.services ? l4d2)
      && !(c.systemd.services ? l4d2-install)
      && !(c.systemd.services ? l4d2-update)
      && !(c.systemd.timers ? l4d2-update)
      && c.networking.firewall.allowedUDPPorts == [ ]
      && c.users.users ? antares;
  }
  {
    name = "l4d2-files";
    module = { };
    check =
      c:
      c.antares.l4d2.fileServer.enable
      && c.services.nginx.enable
      && c.services.nginx.virtualHosts."${host}.chr.fan".onlySSL
      &&
        lib.hasInfix (builtins.unsafeDiscardStringContext "xslt_stylesheet ${../resource/l4d2/files.xsl};")
          c.services.nginx.virtualHosts."${host}.chr.fan".extraConfig
      && lib.all (
        listener: listener.port == 8443 && listener.ssl
      ) c.services.nginx.virtualHosts."${host}.chr.fan".listen
      &&
        c.services.nginx.virtualHosts."${host}.chr.fan".basicAuthFile
        == c.age.secrets.l4d2-files-htpasswd.path
      && c.age.secrets.l4d2-files-htpasswd.owner == "nginx"
      && c.age.secrets.l4d2-files-htpasswd.mode == "0400"
      && c.security.acme.certs."${host}.chr.fan".dnsProvider == "cloudflare"
      && c.security.acme.certs."${host}.chr.fan".webroot == null
      && c.systemd.services.nginx.serviceConfig.ProtectHome
      &&
        c.systemd.services.nginx.serviceConfig.BindReadOnlyPaths == [
          "/home/l4d2/serverfiles/left4dead2/addons:/srv/l4d2-addons"
        ];
  }
  {
    name = "l4d2-files-off";
    module = { lib, ... }: { antares.l4d2.fileServer.enable = lib.mkForce false; };
    check =
      c:
      c.systemd.services ? l4d2
      && !(c.systemd.services ? nginx)
      && !(c.age.secrets ? l4d2-files-htpasswd)
      && !(c.age.secrets ? cloudflareEnv)
      && c.security.acme.certs == { }
      &&
        lib.sort builtins.lessThan c.networking.firewall.allowedTCPPorts == [
          22
          27015
        ];
  }
  {
    name = "l4d2-files-dependency";
    module = { lib, ... }: { services.nginx.enable = lib.mkForce false; };
    valid = false;
    check = c: c.antares.l4d2.fileServer.enable && !c.services.nginx.enable;
  }
  {
    name = "xray-dependency";
    module = { lib, ... }: { services.xray.enable = lib.mkForce false; };
    valid = false;
    check = c: !(c.systemd.services ? xray) && c.antares.proxy.enable;
  }
]
