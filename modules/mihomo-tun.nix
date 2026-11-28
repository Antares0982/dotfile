{
  config,
  lib,
  pkgs,
  ...
}:
let
  proxy = config.antares.proxy;
  interface = config.antares.mihomo.publicInterface;
  server = interface != null;
  wsl = config.wsl.enable or false;
  rules = pkgs.writeText "mihomo-guard.nft" (
    builtins.readFile ../resource/mihomo-guard.nft
    + ''
      flush set inet mihomo_guard public_if
      flush set inet mihomo_guard public_tcp
      flush set inet mihomo_guard public_udp
    ''
    + lib.optionalString (wsl && proxy.lan) ''
      insert rule inet mihomo_guard ingress iifname "loopback0" ip saddr 127.0.0.1 ip daddr 127.0.0.1 meta l4proto { tcp, udp } th dport ${toString config.antares.mihomo.port} accept
    ''
    + lib.optionalString config.virtualisation.waydroid.enable ''
      insert rule inet mihomo_guard ingress iifname "waydroid0" udp dport { 53, 67 } accept
      insert rule inet mihomo_guard ingress iifname "waydroid0" tcp dport 53 accept
      insert rule inet mihomo_guard ingress iifname "waydroid0" meta l4proto tcp ct status dnat accept
      insert rule inet mihomo_guard egress oifname "waydroid0" meta iif 0 accept
      insert rule inet mihomo_guard egress oifname "waydroid0" ct state { established, related } accept
    ''
    + lib.optionalString server ''
      add element inet mihomo_guard public_if { "${interface}" }
      add element inet mihomo_guard public_tcp { ${
        lib.concatMapStringsSep ", " toString config.networking.firewall.allowedTCPPorts
      } }
      ${lib.optionalString (config.networking.firewall.allowedUDPPorts != [ ])
        "add element inet mihomo_guard public_udp { ${
          lib.concatMapStringsSep ", " toString config.networking.firewall.allowedUDPPorts
        } }"
      }
    ''
  );
  routes = pkgs.writeShellScript "mihomo-reply-routes" ''
    set -eu
    for family in -4 -6; do
      ip=${pkgs.iproute2}/bin/ip
      if ! "$ip" "$family" rule show | ${pkgs.gnugrep}/bin/grep -q '^70:.*fwmark 0x4d48 lookup main'; then
        "$ip" "$family" rule add priority 70 fwmark 0x4d48 lookup main
      fi
      ports="${lib.concatMapStringsSep " " toString config.networking.firewall.allowedUDPPorts}"
      existing=$("$ip" "$family" rule show pref 71 | ${pkgs.gnused}/bin/sed -nE 's/^71:[[:space:]]+from all iif lo ipproto udp sport ([0-9]+) lookup main.*/\1/p')
      for port in $existing; do
        case " $ports " in
          *" $port "*) ;;
          *) "$ip" "$family" rule del pref 71 iif lo ipproto udp sport "$port" lookup main ;;
        esac
      done
      # Select the physical UDP reply source.
      for port in $ports; do
        if ! "$ip" "$family" rule show | ${pkgs.gnugrep}/bin/grep -q "^71:.*ipproto udp sport $port lookup main"; then
          "$ip" "$family" rule add priority 71 iif lo ipproto udp sport "$port" lookup main
        fi
      done
    done
  '';
  nft = "${pkgs.nftables}/bin/nft";
  load = "${nft} -f ${rules}";
in
{
  config = lib.mkIf (proxy.enable && proxy.insideGFW) {
    services.mihomo.tunMode = true;
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNS = [ "198.18.0.2" ];
        Domains = [ "~." ];
        FallbackDNS = "";
        MulticastDNS = true;
      };
    };
    networking.networkmanager.settings = lib.mkIf config.networking.networkmanager.enable {
      "global-dns-domain-*".servers = "198.18.0.2";
      connection."connection.mdns" = 2;
    };
    networking.firewall.checkReversePath = lib.mkIf server "loose";
    networking.dhcpcd.extraConfig = lib.mkIf (
      !wsl && !config.networking.networkmanager.enable
    ) "nohook resolv.conf";
    networking.firewall.trustedInterfaces = [ "mihomo0" ];
    environment.etc."opt/chrome/policies/managed/mihomo.json" =
      lib.mkIf (config.networking.hostName == "nixos")
        {
          text = builtins.toJSON {
            WebRtcIPHandling = "disable_non_proxied_udp";
            DnsOverHttpsMode = "off";
          };
        };

    systemd.services.mihomo-guard = {
      description = "Restrict physical network egress";
      wantedBy = [ "sysinit.target" ];
      before = [
        "network-pre.target"
        "NetworkManager.service"
        "mihomo.service"
        "shutdown.target"
      ];
      after = [ "systemd-modules-load.service" ];
      conflicts = [ "shutdown.target" ];
      unitConfig.DefaultDependencies = false;
      reloadIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [ load ] ++ lib.optional server routes;
        ExecReload = [ load ] ++ lib.optional server routes;
        ExecStop = [
          "${nft} destroy table inet mihomo_guard"
        ]
        ++ lib.optionals server [
          "-${pkgs.iproute2}/bin/ip -4 rule del priority 70 fwmark 0x4d48 lookup main"
          "-${pkgs.iproute2}/bin/ip -6 rule del priority 70 fwmark 0x4d48 lookup main"
        ]
        ++ lib.optionals server (
          lib.concatMap (
            port:
            map
              (
                af:
                "-${pkgs.iproute2}/bin/ip ${af} rule del priority 71 iif lo ipproto udp sport ${toString port} lookup main"
              )
              [
                "-4"
                "-6"
              ]
          ) config.networking.firewall.allowedUDPPorts
        );
      };
    };
    systemd.services.NetworkManager = lib.mkIf config.networking.networkmanager.enable {
      requires = [ "mihomo-guard.service" ];
    };
    systemd.services.dhcpcd = lib.mkIf config.networking.dhcpcd.enable {
      after = [ "mihomo-guard.service" ];
      requires = [ "mihomo-guard.service" ];
    };
    systemd.services.mihomo = {
      environment.SKIP_SYSTEM_IPV6_CHECK = "1";
      requires = [ "mihomo-guard.service" ];
      serviceConfig.NFTSet = "user:inet:mihomo_guard:core";
    };
  };
}
