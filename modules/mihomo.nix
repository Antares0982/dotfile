{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.antares.mihomo;
  apps = import inputs.nixpkgs { system = pkgs.stdenv.hostPlatform.system; };
  tools = (import ../packages { pkgs = apps; }).mihomo-tools;
  queue = "/home/agent/agent_work/.agent/mihomo";
  agent = config.antares.agent.enable or false;
  proxy = config.antares.proxy;
  gateway = cfg.lanGateway && proxy.lan && proxy.insideGFW;
  settings = cfg.settings;
  homeRules = pkgs.writeText "mihomo-home.nft" (
    builtins.readFile ../resource/mihomo-home.nft
    + ''
      flush set inet mihomo_home tcp_ports
      flush set inet mihomo_home udp_ports
      add element inet mihomo_home tcp_ports { ${toString cfg.port}, ${toString (cfg.port + 1)}, ${toString (cfg.port + 2)}, 17900${lib.optionalString mobile.enable ", ${toString mobile.port}"} }
      add element inet mihomo_home udp_ports { ${toString cfg.port}, ${toString (cfg.port + 1)}, ${toString (cfg.port + 2)} }
    ''
    + lib.optionalString (config.wsl.enable or false) ''
      insert rule inet mihomo_home ingress iifname "loopback0" ip saddr 127.0.0.1 ip daddr 127.0.0.1 meta l4proto { tcp, udp } th dport ${toString cfg.port} accept
    ''
  );
  template = pkgs.writeText "mihomo-base.json" (builtins.toJSON settings);
  mobile = cfg.mobileRules;
  mobilePolicy = (pkgs.formats.yaml { }).generate "clashmi-pc-routing.yaml" (
    cfg.policy
    // lib.optionalAttrs (settings ? ipv6) { inherit (settings) ipv6; }
    // {
      inherit (settings)
        dns
        mode
        profile
        rules
        ;
      tun.enable = true;
    }
  );
  mobileRoot = pkgs.linkFarm "mihomo-mobile-rules" [
    {
      name = "clashmi-pc-routing.yaml";
      path = mobilePolicy;
    }
  ];
in
{
  imports = [
    ./mihomo-common.nix
    ./mihomo-tun.nix
  ];
  options.antares.mihomo.lanGateway = lib.mkEnableOption "dual-stack transparent home LAN gateway";
  options.antares.mihomo.mobileRules = {
    enable = lib.mkEnableOption "serve public Clash Mi routing overrides on the home LAN";
    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IPv4 address used by the mobile rules HTTP listener.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 18080;
    };
  };
  config = lib.mkIf proxy.enable {
    system.build.mihomo-mobile-rules = lib.mkIf (proxy.lan && mobile.enable) mobileRoot;
    assertions = lib.optional mobile.enable {
      assertion =
        !(builtins.elem mobile.port (
          [
            17900
            17901
          ]
          ++ lib.range cfg.port (cfg.port + 2)
        ));
      message = "Mobile rules must not share a Mihomo proxy or control port.";
    };
    environment.systemPackages = [
      tools
      tools.clashtui
    ];
    age.secrets.mihomoSubscription = {
      file = ../secrets/xraysub.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    services.mihomo = {
      enable = true;
      package = apps.mihomo;
      webui = if proxy.lan then apps.metacubexd else null;
      configFile = "/var/lib/mihomo-config/config.json";
    };
    # A /32 gives local connections the same source address as their target.
    # Otherwise Linux selects 127.0.0.1, whose replies WSL may route to Windows.
    systemd.services.mihomo-loopback = lib.mkIf (proxy.clientAddress != "127.0.0.1") {
      description = "Local Mihomo client address";
      before = [ "mihomo.service" ];
      requiredBy = [ "mihomo.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip address replace ${proxy.clientAddress}/32 dev lo";
        ExecStop = "${pkgs.iproute2}/bin/ip address del ${proxy.clientAddress}/32 dev lo";
      };
    };
    systemd.services.mihomo-home = lib.mkIf proxy.lan {
      wantedBy = [ "sysinit.target" ];
      before = [
        "network-pre.target"
        "mihomo.service"
        "mihomo-mobile-rules.service"
      ];
      after = [ "systemd-modules-load.service" ];
      unitConfig.DefaultDependencies = false;
      reloadIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.nftables}/bin/nft -f ${homeRules}";
        ExecReload = "${pkgs.nftables}/bin/nft -f ${homeRules}";
        ExecStop = "${pkgs.nftables}/bin/nft destroy table inet mihomo_home";
      };
    };
    systemd.services.mihomo-home-watch = lib.mkIf proxy.lan {
      wantedBy = [ "multi-user.target" ];
      after = [ "mihomo-home.service" ] ++ lib.optional gateway "mihomo-gateway.service";
      requires = [ "mihomo-home.service" ];
      path = [
        pkgs.iproute2
        pkgs.nftables
      ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${../resource/mihomo-home.py}${lib.optionalString gateway " --gateway"}";
        Restart = "always";
      };
    };
    systemd.services.mihomo-config = {
      description = "Prepare private Mihomo configuration";
      environment.MIHOMO_CLIENT_ADDRESS = proxy.clientAddress;
      before = [ "mihomo.service" ];
      requiredBy = [ "mihomo.service" ];
      restartTriggers = [
        template
        config.age.secrets.mihomoSubscription.file
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
        ExecStart = "${pkgs.python3}/bin/python3 ${../resource/mihomo-prepare.py} ${template} ${config.age.secrets.mihomoSubscription.path}";
      };
    };
    systemd.services.mihomo = {
      after = [ "mihomo-config.service" ];
      requires = [ "mihomo-config.service" ] ++ lib.optional proxy.lan "mihomo-home.service";
      restartTriggers = [
        template
        config.age.secrets.mihomoSubscription.file
      ];
      environment = {
        MIHOMO_CLIENT_ADDRESS = proxy.clientAddress;
      }
      // lib.optionalAttrs proxy.lan { SAFE_PATHS = "${apps.metacubexd}"; };
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "3s";
        ExecStartPost = "${tools}/bin/mihomoctl ready";
        TimeoutStartSec = "180s";
      };
    };
    systemd.tmpfiles.rules = [
      "f /run/lock/mihomo-speed-test.lock 0666 root root - -"
    ]
    ++ lib.optionals agent (
      map (path: "d ${queue}${path} 0770 agent agent - -") [
        ""
        "/requests"
        "/processing"
        "/results"
      ]
    );
    systemd.services.mihomo-mobile-rules = lib.mkIf (proxy.lan && mobile.enable) {
      description = "Public Clash Mi routing override";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mihomo-home.service" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${pkgs.python3}/bin/python3"
          "${../resource/mihomo-mobile.py}"
          mobile.address
          (toString mobile.port)
          "${mobileRoot}"
        ];
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
    networking.firewall.extraCommands = lib.mkMerge [
      (lib.mkIf gateway (builtins.readFile ../resource/mihomo-gateway-firewall.sh))
      (lib.mkIf proxy.lan ''
        iptables -A nixos-fw -s 192.168.0.0/24 -p tcp -m multiport --dports ${toString cfg.port},${toString (cfg.port + 1)},${toString (cfg.port + 2)},17900 -j nixos-fw-accept
        iptables -A nixos-fw -s 192.168.0.0/24 -p udp -m multiport --dports ${toString cfg.port},${toString (cfg.port + 1)},${toString (cfg.port + 2)} -j nixos-fw-accept
      '')
      (lib.mkIf (proxy.lan && mobile.enable) ''
        iptables -A nixos-fw -s 192.168.0.0/24 -p tcp --dport ${toString mobile.port} -j nixos-fw-accept
      '')
    ];
    systemd.services.mihomo-worker = lib.mkIf agent {
      description = "Restricted Mihomo agent actions";
      after = [ "mihomo.service" ];
      environment.XDG_CACHE_HOME = "/var/cache/mihomo-worker";
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        User = "mihomo-worker";
        Group = "agent";
        ExecStart = "${tools}/bin/mihomoctl worker";
        LoadCredential = "connection.json:/run/mihomo-client/connection.json";
        TimeoutStartSec = "30min";
        Restart = "on-failure";
        RestartSec = "2s";
        CacheDirectory = "mihomo-worker";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "tmpfs";
        BindPaths = [ queue ];
        ReadWritePaths = [ "/run/lock/mihomo-speed-test.lock" ];
        PrivateTmp = true;
        UMask = "0007";
      };
    };
    systemd.paths.mihomo-worker = lib.mkIf agent {
      wantedBy = [ "paths.target" ];
      pathConfig = {
        DirectoryNotEmpty = "${queue}/requests";
        PathExistsGlob = "${queue}/processing/*.json";
      };
    };
    systemd.services.mihomo-agent-guide = lib.mkIf agent {
      description = "Update agent proxy instructions";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "antares-agent.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "agent";
        Group = "agent";
        ExecStart = "${pkgs.coreutils}/bin/install -D -m 0644 ${../resource/mihomo-skill/SKILL.md} /home/agent/agent_work/.agents/skills/mihomo/SKILL.md";
        NoNewPrivileges = true;
      };
    };
  };
}
