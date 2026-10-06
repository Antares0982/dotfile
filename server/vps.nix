{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./xray-client.nix
    ../common/nix.nix
    ../common/ssh.nix
    ../common/sudo.nix
    ../common/time.nix
    ../common/zsh.nix
    ../common/packages.nix
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
    secrets.serverPassword.file = ../secrets/serverPassword.age;
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
