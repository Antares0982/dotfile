{
  config,
  pkgs,
  lib,
  ...
}:
{
  antares.proxy = {
    enable = true;
    insideGFW = true;
    lan = true;
    # Mirrored networking redirects 127.0.0.1 through Windows' loopback0.
    clientAddress = "127.0.0.2";
  };
  # WSL's existing redirect rules conflict with Mihomo's auto-redirect setup.
  antares.mihomo.autoRedirect = false;
  antares.windowsShell.enable = true;
  antares.starship = {
    enable = true;
    settings.palettes.host.color_os = "#00af00";
  };
  antares.gitSignUnlock.enable = true;
  programs.ssh.startAgent = true;
  programs.zsh.shellInit = ''
    export COLORTERM=truecolor
  '';
  environment.variables.NIX_DOT_FILES = "${config.users.users.antares.home}/Nix";
  age.identityPaths = [ "/etc/ssh/agenix" ];
  wsl.enable = true;
  # Keep a Windows-side WSL client attached after the last terminal closes.
  systemd.services.wsl-keepalive = {
    description = "Keep the NixOS WSL distribution running";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = "/mnt/c";
    serviceConfig = {
      User = config.wsl.defaultUser;
      ExecStart = "/mnt/c/Windows/System32/wsl.exe --distribution NixOS --user ${config.wsl.defaultUser} --exec ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "always";
      RestartSec = "5s";
    };
  };
  programs.direnv.enable = false;
  nixpkgs.config.allowUnfree = true;
  imports = [
    ../modules/proxy.nix
    ../modules/mihomo.nix
    ../modules/windows-shell.nix
    ./git-sign-unlock.nix
    ./network.nix
    ./packages.nix
    ./user.nix
  ]
  ++ [
    ../common/env.nix
    ../common/git-sign.nix
    ../common/nix.nix
    ../common/nix-zshell.nix
    ../common/sudo.nix
    ../common/time.nix
    ../common/zsh.nix
  ];
  system.stateVersion = "25.05";
}
