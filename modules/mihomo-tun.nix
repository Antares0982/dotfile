{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.antares.mihomo;
  nft = "${pkgs.nftables}/bin/nft";
  load = "${nft} -f ${../resource/mihomo-guard.nft}";
in
{
  options.antares.mihomo.tun.enable =
    lib.mkEnableOption "dual-stack desktop routing with fail-closed egress";

  config = lib.mkIf (cfg.enable && cfg.tun.enable) {
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
    networking.networkmanager.settings = {
      "global-dns-domain-*".servers = "198.18.0.2";
      connection."connection.mdns" = 2;
    };
    networking.firewall.trustedInterfaces = [ "mihomo0" ];
    environment.etc."opt/chrome/policies/managed/mihomo.json".text = builtins.toJSON {
      WebRtcIPHandling = "disable_non_proxied_udp";
      DnsOverHttpsMode = "off";
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
        ExecStart = load;
        ExecReload = load;
        ExecStop = "${nft} destroy table inet mihomo_guard";
      };
    };
    systemd.services.NetworkManager.requires = [ "mihomo-guard.service" ];
    systemd.services.mihomo = {
      requires = [ "mihomo-guard.service" ];
      serviceConfig.NFTSet = "user:inet:mihomo_guard:core";
    };
  };
}
