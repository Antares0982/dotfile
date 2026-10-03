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
      && builtins.attrNames c.age.secrets == [ "serverPassword" ]
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
      && c.networking.firewall.allowedUDPPorts == [ ];
  }
]
