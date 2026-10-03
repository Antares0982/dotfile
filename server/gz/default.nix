{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../common/nix.nix
    ../../common/ssh.nix
    ../../common/sudo.nix
    ../../common/time.nix
    ../../common/zsh.nix
  ];

  boot = {
    loader.grub.enable = true;
    kernelParams = [
      "net.ifnames=0"
      "console=ttyS0,115200"
      "console=tty0"
    ];
    tmp.cleanOnBoot = true;
  };
  networking = {
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };
  zramSwap.enable = true;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  age = {
    identityPaths = [ "/etc/ssh/agenix" ];
    secrets.serverPassword.file = ../../secrets/serverPassword.age;
  };
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
    users.antares = {
      isNormalUser = true;
      home = "/home/antares";
      description = "Antares0982";
      extraGroups = [ "wheel" ];
      uid = 1000;
      useDefaultShell = true;
      hashedPasswordFile = config.age.secrets.serverPassword.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS4Ty97Xiann8mMJHDjv5HqCzdideBuPq28PeVSHvZH antares@gz"
      ];
      linger = true;
    };
  };
  environment.systemPackages = with pkgs; [
    git
    kitty.terminfo
    nano
    rsync
  ];
}
