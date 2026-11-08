{ lib }: [
  {
    name = "mihomo-on";
    module = { };
    check =
      c:
      c.antares.mihomo.enable
      && c.antares.mihomo.singapore
      && !c.antares.mihomo.lan
      && c.antares.mihomo.settings.mixed-port == 1081
      &&
        map (entry: entry.port) c.antares.mihomo.settings.listeners == [
          1082
          1083
          17901
        ]
      && !(c.antares.mihomo.settings ? sub-rules)
      && (builtins.head c.antares.mihomo.settings.listeners).proxy == "GLOBAL"
      &&
        (lib.findFirst (g: g.name == "GLOBAL") { } c.antares.mihomo.policy.proxy-groups).default-selected
        == "SG"
      &&
        (lib.findFirst (g: g.name == "Telegram") { } c.antares.mihomo.policy.proxy-groups).proxies == [
          "SG"
          "JP"
          "其他"
          "全部节点"
        ]
      && c.antares.mihomo.settings.bind-address == "127.0.0.1"
      && c.antares.mihomo.settings.external-controller == "0.0.0.0:17900"
      && lib.all (listener: listener.listen == "127.0.0.1") c.antares.mihomo.settings.listeners
      && c.launchd.daemons.mihomo.serviceConfig.RunAtLoad
      && c.launchd.daemons.mihomo.serviceConfig.KeepAlive
      && lib.any (lib.hasSuffix "-mihomo-darwin.py") (
        builtins.attrNames (builtins.getContext c.launchd.daemons.mihomo.command)
      )
      && lib.any (lib.hasSuffix "-mihomo-prepare.py") (
        builtins.attrNames (builtins.getContext c.launchd.daemons.mihomo.command)
      )
      && !(c.launchd.daemons ? xray)
      && c.age.secrets.mihomoSubscription.owner == "antares"
      && c.age.secrets.mihomoSubscription.group == "staff"
      && c.age.secrets.mihomoSubscription.mode == "0400"
      && c.age.identityPaths == [ "/etc/ssh/ssh_host_ed25519_key" ]
      && c.antares.proxy.socksUrl == "socks5h://127.0.0.1:1081";
  }
  {
    name = "mihomo-off";
    module = { lib, ... }: {
      antares.mihomo.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.launchd.daemons ? xray)
      && !(c.launchd.daemons ? mihomo)
      && !(c.age.secrets ? mihomoSubscription)
      && !(c.launchd.daemons.nix-daemon.environment ? http_proxy)
      && !(c.launchd.daemons.nix-daemon.environment ? all_proxy);
  }
  {
    name = "mihomo-dependency";
    module = { lib, ... }: { antares.mihomo.enable = lib.mkForce false; };
    check = c: true;
    valid = false;
  }
  {
    name = "mihomo-local-dashboard";
    module = { lib, ... }: { antares.mihomo.dashboardLan = lib.mkForce false; };
    check = c: c.antares.mihomo.settings.external-controller == "127.0.0.1:17900";
  }
  {
    name = "mihomo-invalid-port";
    module = { lib, ... }: { antares.mihomo.port = lib.mkForce 17900; };
    check = c: true;
    valid = false;
  }
  {
    name = "nix-shell-off";
    module = { lib, ... }: { antares.nixShell.enable = lib.mkForce false; };
    check = c: !(c.environment.variables ? NIX_BUILD_SHELL) && c.environment.variables ? NIX_DOT_FILES;
  }
  {
    name = "system-compiler-off";
    module = { lib, ... }: { antares.systemCompiler.enable = lib.mkForce false; };
    check = c: !(lib.hasInfix "system-cc-shims" c.environment.extraInit);
  }
  {
    name = "all-features-off";
    module = { lib, ... }: {
      antares.xray.enable = lib.mkForce false;
      antares.mihomo.enable = lib.mkForce false;
      antares.proxy.enable = lib.mkForce false;
      antares.nixShell.enable = lib.mkForce false;
      antares.systemCompiler.enable = lib.mkForce false;
    };
    check =
      c:
      !(c.launchd.daemons ? xray)
      && !(c.launchd.daemons ? mihomo)
      && !(c.age.secrets ? mihomoSubscription)
      && !(c.environment.variables ? NIX_BUILD_SHELL);
  }
]
