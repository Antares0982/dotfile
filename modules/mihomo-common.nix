{ config, lib, ... }:
let
  cfg = config.antares.mihomo;
  base = builtins.fromJSON (builtins.readFile ../resource/mihomo-base.json);
  address = if cfg.lan then "0.0.0.0" else "127.0.0.1";
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
      external-controller = "${if cfg.dashboardLan then "0.0.0.0" else "127.0.0.1"}:17900";
      external-controller-cors = {
        allow-origins = [
          "http://127.0.0.1:17900"
          "http://localhost:17900"
        ]
        ++ cfg.dashboardOrigins;
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
in
{
  options.antares.mihomo = {
    enable = lib.mkEnableOption "Mihomo proxy with terminal and web management";
    port = lib.mkOption {
      type = lib.types.port;
      default = 1081;
    };
    singapore = lib.mkEnableOption "separate Singapore proxy entrance";
    lan = lib.mkEnableOption "proxy access from the home LAN";
    dashboardLan = lib.mkOption {
      type = lib.types.bool;
      default = cfg.lan;
      description = "Listen for dashboard connections on IPv4 interfaces.";
    };
    dashboardOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional dashboard origins allowed by the control API.";
    };
    settings = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = settings;
    };
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
  };
}
