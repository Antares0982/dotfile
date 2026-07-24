{ pkgs, ... }:
{
  # mcp-nixos run as a long-lived HTTP MCP server on loopback. Claude Code
  # (and any other local MCP client) connects to http://127.0.0.1:8000/mcp
  # instead of spawning its own stdio process.
  systemd.services.mcp-nixos = {
    description = "MCP NixOS server (HTTP)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      MCP_NIXOS_TRANSPORT = "http";
      MCP_NIXOS_HOST = "127.0.0.1";
      MCP_NIXOS_PORT = "61080";
      # Outbound queries to the NixOS search/elasticsearch APIs go through the
      # local xray proxy, consistent with the rest of this host.
      http_proxy = "http://127.0.0.1:1081";
      https_proxy = "http://127.0.0.1:1081";
      # Cache dir lives under the service's CacheDirectory.
      HOME = "/var/cache/mcp-nixos";
    };

    serviceConfig = {
      ExecStart = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      DynamicUser = true;
      CacheDirectory = "mcp-nixos";
      Restart = "on-failure";
      RestartSec = 5;

      # Hardening.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
    };
  };
}
