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
    "category-ai-!cn"
    "telegram"
    "netflix"
    "youtube"
  ];
  provider = kind: name: {
    type = "http";
    behavior = if kind == "geosite" then "domain" else "ipcidr";
    format = "mrs";
    url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/${kind}/${name}.mrs";
    path = "./rules/${name}${lib.optionalString (kind == "geoip") "-ip"}.mrs";
    interval = 86400;
    proxy = "JP";
  };
  providers =
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = provider "geosite" name;
      }) domains
    )
    // builtins.listToAttrs (
      map
        (name: {
          name = "${name}-ip";
          value = provider "geoip" name;
        })
        [
          "cn"
          "telegram"
          "netflix"
        ]
    );
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
    base.rules
    ++ [
      "RULE-SET,category-ads-all,REJECT"
    ]
    ++ map (domain: "DOMAIN-KEYWORD,${domain},REJECT") blocked
    ++ [
      "RULE-SET,category-ai-!cn,AI"
      "RULE-SET,telegram,Telegram"
      "RULE-SET,telegram-ip,Telegram,no-resolve"
      "RULE-SET,netflix,Netflix"
      "RULE-SET,netflix-ip,Netflix,no-resolve"
      "RULE-SET,youtube,YouTube"
      "RULE-SET,private,DIRECT"
    ]
    ++ map (name: "RULE-SET,${name},国内") [
      "cn"
      "apple-cn"
      "google-cn"
      "tld-cn"
      "category-games@cn"
    ]
    ++ map (keyword: "DOMAIN-KEYWORD,${keyword},DIRECT") [
      "torrent"
      "peer_id="
      "info_hash"
      "get_peers"
      "find_node"
      "BitTorrent"
      "announce_peer"
    ]
    ++ [
      "RULE-SET,cn-ip,国内"
      "MATCH,其他"
    ];
  regionGroup = name: filter: {
    inherit name filter;
    type = "select";
    include-all = true;
    empty-fallback = "REJECT";
  };
  regions = [ "JP" ] ++ lib.optional cfg.singapore "SG";
  choices = regions ++ [ "全部节点" ];
  selectGroup = name: proxies: {
    inherit name proxies;
    type = "select";
  };
  groups = [
    (selectGroup "其他" choices)
    (selectGroup "Telegram" (
      (lib.reverseList regions)
      ++ [
        "其他"
        "全部节点"
      ]
    ))
    (selectGroup "AI" ([ "其他" ] ++ choices))
    (selectGroup "Netflix" ([ "其他" ] ++ choices))
    (selectGroup "YouTube" ([ "其他" ] ++ choices))
    (selectGroup "国内" ([ "DIRECT" ] ++ choices))
    (regionGroup "JP" "(?i)Japan|日本|🇯🇵|\\bJP\\b")
  ]
  ++ lib.optional cfg.singapore (regionGroup "SG" "(?i)Singapore|新加坡|狮城|🇸🇬|\\bSG\\b")
  ++ [ (regionGroup "全部节点" ".*") ];
  policy = {
    proxy-groups = groups ++ [
      (
        (selectGroup "GLOBAL" ((map (group: group.name) groups) ++ [ "DIRECT" ]))
        // {
          default-selected = if cfg.singapore then "SG" else "JP";
        }
      )
    ];
    rule-providers = providers;
    inherit rules;
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
    // policy
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
      proxy-groups = policy.proxy-groups ++ [ ((regionGroup "BENCH" ".*") // { hidden = true; }) ];
      listeners = [
        (listener "global" (cfg.port + 1) "GLOBAL")
        (listener "direct" (cfg.port + 2) "DIRECT")
        (
          (listener "bandwidth-test" 17901 "BENCH")
          // {
            listen = "127.0.0.1";
            udp = false;
          }
        )
      ];
    };
in
{
  options.antares.mihomo = {
    enable = lib.mkEnableOption "Mihomo proxy with terminal and web management";
    port = lib.mkOption {
      type = lib.types.port;
      default = 1081;
    };
    singapore = lib.mkEnableOption "Singapore nodes for service policy groups";
    lan = lib.mkEnableOption "proxy access from the home LAN";
    dashboard = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the WebUI; the authenticated control API remains available.";
    };
    dashboardLan = lib.mkOption {
      type = lib.types.bool;
      default = cfg.dashboard && cfg.lan;
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
    policy = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = policy;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.port <= 65533
          && !(builtins.elem 17900 (lib.range cfg.port (cfg.port + 2)))
          && !(builtins.elem 17901 (lib.range cfg.port (cfg.port + 2)));
        message = "Mihomo proxy ports must not overlap control or test ports.";
      }
    ];
  };
}
