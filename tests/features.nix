{
  root,
  host,
  snapshot ? false,
  flake ? builtins.getFlake "git+file://${root}?dir=hosts/${host}",
}:
let
  darwin = host == "macbook";
  system = if darwin then flake.darwinConfigurations.${host} else flake.nixosConfigurations.${host};
  lib = system.pkgs.lib;
  cfg = system.config;
  casesFile = ./. + "/${host}.nix";
  allCases = [
    {
      name = "proxy-host";
      module = { };
      check =
        c:
        let
          proxy = c.antares.proxy;
          settings = c.antares.mihomo.settings;
          inside =
            !(lib.elem host [
              "hk"
              "gz"
            ]);
          lan = lib.elem host [
            "nixos"
            "rpi5"
            "macbook"
            "wsl"
          ];
        in
        proxy.enable
        && proxy.insideGFW == inside
        && proxy.lan == lan
        && settings.tun.enable == inside
        && (settings.tun.auto-redirect or false) == (inside && host != "wsl" && host != "sz" && !darwin)
        && settings.allow-lan == lan
        && settings.ipv6
        && settings.dns.ipv6
        && settings.dns.nameserver == [ "https://1.1.1.1/dns-query#其他" ]
        && settings.dns.nameserver-policy."rule-set:cn" == "https://223.5.5.5/dns-query#DIRECT"
        && settings.mixed-port == 1081
        && settings.rules == c.antares.mihomo.policy.rules
        && c.age.secrets ? mihomoSubscription;
    }
    (import ./zsh.nix { inherit lib host; })
  ]
  ++ (import ./starship.nix { inherit lib host; })
  ++ (import ./direnv.nix { inherit lib host; })
  ++ (if builtins.pathExists casesFile then import casesFile { inherit lib; } else [ ]);
  pattern = builtins.getEnv "CHECK_CASE";
  cases = lib.filter (case: pattern == "" || builtins.match pattern case.name != null) allCases;
  drv =
    evaluated:
    if darwin then evaluated.system.drvPath else evaluated.config.system.build.toplevel.drvPath;
  run =
    case:
    let
      evaluated =
        if case.module == { } then system else system.extendModules { modules = [ case.module ]; };
      checked = case.check evaluated.config;
      valid = lib.all (entry: entry.assertion) evaluated.config.assertions;
    in
    assert lib.assertMsg checked "${host}: ${case.name}";
    assert lib.assertMsg (valid == (case.valid or true)) "${host}: ${case.name} assertions";
    if case.valid or true then builtins.seq (drv evaluated) true else true;
in
assert lib.assertMsg (
  pattern == "" || cases != [ ]
) "No matching feature checks for ${host}: ${pattern}";
if snapshot then
  {
    users = lib.mapAttrs (_: user: {
      inherit (user) home uid shell;
      groups = lib.sort builtins.lessThan (user.extraGroups or [ ]);
    }) cfg.users.users;
    packages = map toString cfg.environment.systemPackages;
  }
  // (
    if darwin then
      {
        daemons = lib.mapAttrs (_: daemon: {
          inherit (daemon) script serviceConfig environment;
        }) cfg.launchd.daemons;
      }
    else
      {
        secrets = lib.mapAttrs (_: secret: {
          inherit (secret)
            file
            owner
            group
            mode
            ;
        }) (cfg.age.secrets or { });
        services = lib.mapAttrs (_: service: {
          inherit (service)
            serviceConfig
            environment
            script
            preStart
            postStart
            ;
        }) cfg.systemd.services;
        timers = lib.mapAttrs (_: timer: { inherit (timer) timerConfig wantedBy; }) cfg.systemd.timers;
        paths = lib.mapAttrs (_: path: { inherit (path) pathConfig wantedBy; }) cfg.systemd.paths;
        firewall = {
          inherit (cfg.networking.firewall)
            enable
            allowedTCPPorts
            allowedUDPPorts
            allowedTCPPortRanges
            allowedUDPPortRanges
            ;
        };
      }
  )
else
  {
    toplevel = drv system;
    cases = builtins.listToAttrs (
      map (case: {
        name = case.name;
        value = run case;
      }) cases
    );
  }
