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
  base = builtins.fromJSON (builtins.readFile ../resource/mihomo-base.json);
  address = if cfg.lan then "0.0.0.0" else "127.0.0.1";
  queue = "/home/agent/agent_work/.agent/mihomo";
  agent = config.antares.agent.enable or false;
  domains = [
    "cn"
    "private"
    "apple-cn"
    "google-cn"
    "tld-cn"
    "category-games@cn"
    "category-ads-all"
  ];
  providers =
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = {
          type = "http";
          behavior = "domain";
          format = "mrs";
          url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/${name}.mrs";
          path = "./rules/${name}.mrs";
          interval = 86400;
          proxy = "JP";
        };
      }) domains
    )
    // {
      cn-ip = base.rule-providers.cn-ip // {
        proxy = "JP";
      };
    };
  blocked = [
    "config.cmpassport.com"
    "www.cmpassport.com"
    "wap.cmpassport.com"
    "onekey1.cmpassport.com"
    "log1.cmpassport.com"
    "smsks1.cmpassport.com"
    "verify.cmpassport.com"
    "opencloud.wostore.cn"
    "auth.wosms.cn"
    "id.mail.wo.cn"
    "mdn.open.wo.cn"
    "hmrz.wo.cn"
    "nishub1.10010.com"
    "nissc1.10010.com"
    "enrichgw.10010.com"
    "id6.me"
    "open.e.189.cn"
    "114dev.com"
    "onepass.geetest.com"
  ];
  rules =
    region:
    [
      "DOMAIN-KEYWORD,claude,${region}"
      "DOMAIN-KEYWORD,chatgpt,${region}"
      "RULE-SET,category-ads-all,REJECT"
    ]
    ++ map (domain: "DOMAIN-KEYWORD,${domain},REJECT") blocked
    ++ map (name: "RULE-SET,${name},DIRECT") (lib.remove "category-ads-all" domains)
    ++ map (keyword: "DOMAIN-KEYWORD,${keyword},DIRECT") [
      "torrent"
      "peer_id="
      "info_hash"
      "get_peers"
      "find_node"
      "BitTorrent"
      "announce_peer"
    ]
    ++ lib.filter (
      rule:
      lib.hasPrefix "IP-CIDR" rule || lib.hasPrefix "DOMAIN," rule || lib.hasPrefix "DOMAIN-SUFFIX," rule
    ) base.rules
    ++ [
      "RULE-SET,cn-ip,DIRECT"
      "MATCH,${region}"
    ];
  regionGroup = name: filter: {
    inherit name filter;
    type = "select";
    use = [ "subscription" ];
    empty-fallback = "REJECT";
  };
  listener = name: port: proxy: {
    inherit name port proxy;
    type = "mixed";
    listen = address;
    udp = true;
  };
  settings =
    builtins.removeAttrs base [
      "socks-port"
      "port"
      "listeners"
      "proxy-groups"
      "rule-providers"
      "rules"
    ]
    // {
      allow-lan = cfg.lan;
      bind-address = address;
      lan-allowed-ips = [
        "127.0.0.0/8"
        "192.168.0.0/24"
      ];
      mixed-port = cfg.port;
      external-controller = "${address}:17900";
      external-controller-cors = {
        allow-origins = [
          "http://127.0.0.1:17900"
          "http://localhost:17900"
        ]
        ++ lib.optional cfg.lan "http://192.168.0.3:17900";
        allow-private-network = true;
      };
      proxy-groups = [
        (regionGroup "JP" "(?i)Japan|日本|🇯🇵|\\bJP\\b")
      ]
      ++ lib.optional cfg.singapore (regionGroup "SG" "(?i)Singapore|新加坡|狮城|🇸🇬|\\bSG\\b")
      ++ [ ((regionGroup "BENCH" ".*") // { hidden = true; }) ];
      listeners = [
        (listener "global-jp" (cfg.port + 1) "JP")
        (listener "direct" (cfg.port + 2) "DIRECT")
        (
          (listener "bandwidth-test" 17901 "BENCH")
          // {
            listen = "127.0.0.1";
            udp = false;
          }
        )
      ]
      ++ lib.optional cfg.singapore {
        name = "singapore";
        type = "mixed";
        listen = address;
        port = cfg.port + 3;
        rule = "singapore";
        udp = true;
      };
      rules = rules "JP";
      sub-rules = lib.optionalAttrs cfg.singapore { singapore = rules "SG"; };
      rule-providers = providers;
    };
  template = pkgs.writeText "mihomo-base.json" (builtins.toJSON settings);
in
{
  options.antares.mihomo = {
    enable = lib.mkEnableOption "Mihomo proxy with terminal and web management";
    port = lib.mkOption {
      type = lib.types.port;
      default = 1081;
    };
    singapore = lib.mkEnableOption "separate Singapore proxy entrance";
    lan = lib.mkEnableOption "access from the home LAN";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.port <= 65532
          && !(builtins.elem 17900 (lib.range cfg.port (cfg.port + 3)))
          && !(builtins.elem 17901 (lib.range cfg.port (cfg.port + 3)));
        message = "Mihomo proxy ports must not overlap control or test ports.";
      }
    ];
    environment.systemPackages = [
      tools
      apps.clashtui
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
      webui = apps.metacubexd;
      configFile = "/var/lib/mihomo-config/config.json";
    };
    systemd.services.mihomo-config = {
      description = "Prepare private Mihomo configuration";
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
      requires = [ "mihomo-config.service" ];
      restartTriggers = [
        template
        config.age.secrets.mihomoSubscription.file
      ];
      environment.SAFE_PATHS = "${apps.metacubexd}";
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
    networking.firewall = lib.mkIf cfg.lan {
      extraCommands = ''
        iptables -A nixos-fw -i end0 -s 192.168.0.0/24 -p tcp -m multiport --dports ${toString cfg.port},${toString (cfg.port + 1)},${toString (cfg.port + 2)},17900 -j nixos-fw-accept
        iptables -A nixos-fw -i end0 -s 192.168.0.0/24 -p udp -m multiport --dports ${toString cfg.port},${toString (cfg.port + 1)},${toString (cfg.port + 2)} -j nixos-fw-accept
      '';
    };
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
        ExecStart = "${pkgs.coreutils}/bin/install -D -m 0644 ${../resource/mihomo-skill/SKILL.md} /home/agent/agent_work/.agents/skills/xray-switch/SKILL.md";
        NoNewPrivileges = true;
      };
    };
  };
}
