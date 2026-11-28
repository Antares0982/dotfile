{ lib }:
[
  {
    name = "mihomo-wsl-loopback";
    module.antares.proxy.enable = lib.mkForce true;
    check =
      c:
      let
        settings = c.antares.mihomo.settings;
        bench = lib.findFirst (entry: entry.name == "bandwidth-test") { } settings.listeners;
      in
      c.antares.proxy.httpUrl == "http://127.0.0.2:1081"
      && c.antares.proxy.socksUrl == "socks5h://127.0.0.2:1081"
      && c.systemd.services.nix-daemon.environment.https_proxy == c.antares.proxy.httpUrl
      && c.systemd.services.mihomo.environment.MIHOMO_CLIENT_ADDRESS == "127.0.0.2"
      && c.systemd.services.mihomo-config.environment.MIHOMO_CLIENT_ADDRESS == "127.0.0.2"
      && c.systemd.services.mihomo-loopback.requiredBy == [ "mihomo.service" ]
      && c.systemd.services.mihomo-loopback.before == [ "mihomo.service" ]
      && c.systemd.services.mihomo-loopback.serviceConfig.RemainAfterExit
      && settings.tun.auto-route
      && !settings.tun.auto-redirect
      && settings.bind-address == "0.0.0.0"
      && settings.external-controller == "0.0.0.0:17900"
      && bench.listen == "127.0.0.2"
      && !bench.udp;
  }
  {
    name = "mihomo-wsl-off";
    module = { };
    check =
      c:
      !c.antares.proxy.enable
      && c.wsl.wslConf.network.generateResolvConf
      && !(c.systemd.services ? mihomo)
      && !(c.systemd.services ? mihomo-guard)
      && !(c.systemd.services ? mihomo-home)
      && !(c.systemd.services ? mihomo-loopback)
      && !(c.systemd.services ? mihomo-config)
      &&
        lib.all
          (
            key:
            !(builtins.hasAttr key c.environment.variables)
            && !(builtins.hasAttr key c.systemd.services.nix-daemon.environment)
          )
          [
            "http_proxy"
            "https_proxy"
          ]
      && !(c.age.secrets ? mihomoSubscription);
  }
  {
    name = "mihomo-wsl-without-lan";
    module.antares.proxy = {
      enable = lib.mkForce true;
      lan = lib.mkForce false;
    };
    check =
      c:
      c.antares.mihomo.settings.bind-address == "127.0.0.2"
      && c.antares.mihomo.settings.external-controller == "127.0.0.2:17900"
      && lib.all (entry: entry.listen == "127.0.0.2") c.antares.mihomo.settings.listeners;
  }
  {
    name = "windows-shell-on";
    module = { };
    check =
      c:
      c.antares.windowsShell.enable
      && c.system.build ? windowsShell
      && c.environment.etc ? "windows-shell/env.zsh"
      && c.environment.etc ? "windows-shell/interactive.zsh"
      && c.environment.etc ? "windows-shell/starship.toml"
      && c.environment.etc ? "windows-shell/starship-git.toml";
  }
  {
    name = "windows-shell-off";
    module.antares.windowsShell.enable = lib.mkForce false;
    check =
      c:
      !(c.system.build ? windowsShell)
      && !(c.environment.etc ? "windows-shell/env.zsh")
      && !(c.environment.etc ? "windows-shell/interactive.zsh")
      && !(c.environment.etc ? "windows-shell/starship.toml")
      && !(c.environment.etc ? "windows-shell/starship-git.toml")
      && c.programs.zsh.enable
      && c.programs.zoxide.enable
      && c.users.users ? antares;
  }
  {
    name = "windows-shell-without-starship";
    module.antares.starship.enable = lib.mkForce false;
    check =
      c:
      c.environment.etc ? "windows-shell/env.zsh"
      && !(c.environment.etc ? "windows-shell/starship.toml")
      && !(c.environment.etc ? "windows-shell/starship-git.toml");
  }
  {
    name = "wsl-host";
    module = { };
    check =
      c:
      c.networking.hostName == "wsl"
      && c.wsl.wslConf.network.hostname == "wsl"
      && c.environment.variables.NIX_DOT_FILES == "${c.users.users.antares.home}/Nix"
      && c.age.identityPaths == [ "/etc/ssh/agenix" ];
  }
  {
    name = "git-sign-unlock-on";
    module = { };
    check =
      c:
      let
        secret = c.age.secrets.gitSignPassphrase;
        service = c.systemd.services.git-sign-unlock;
        trigger = c.systemd.user.services.git-sign-unlock;
      in
      builtins.attrNames c.age.secrets == [ "gitSignPassphrase" ]
      && secret.owner == "root"
      && secret.group == "root"
      && secret.mode == "0400"
      && c.programs.ssh.startAgent
      && service.serviceConfig.User == "root"
      && service.environment.SSH_AUTH_SOCK == "/run/user/${toString c.users.users.antares.uid}/ssh-agent"
      && service.environment.SSH_ASKPASS_REQUIRE == "force"
      && service.wantedBy == [ ]
      && trigger.unitConfig.ConditionUser == "antares"
      && trigger.after == [ "ssh-agent.service" ]
      && trigger.requires == [ "ssh-agent.service" ]
      && trigger.partOf == [ "ssh-agent.service" ]
      &&
        trigger.wantedBy == [
          "default.target"
          "ssh-agent.service"
        ];
  }
  {
    name = "git-sign-unlock-off";
    module.antares.gitSignUnlock.enable = lib.mkForce false;
    check =
      c:
      !(c.systemd.services ? git-sign-unlock)
      && !(c.systemd.user.services ? git-sign-unlock)
      && builtins.attrNames c.age.secrets == [ ]
      && c.programs.ssh.startAgent
      && c.users.users ? antares;
  }
  {
    name = "git-sign-unlock-dependency";
    module.programs.ssh.startAgent = lib.mkForce false;
    check = c: true;
    valid = false;
  }
]
