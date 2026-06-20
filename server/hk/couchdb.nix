{
  config,
  lib,
  pkgs,
  ...
}:

let
  couchRateLimitZone = "couch_zone";
in
{
  services.couchdb = {
    enable = true;

    # [chttpd] bind_address / port
    bindAddress = "127.0.0.1";
    port = 5984;

    # [admins]
    #
    # Do NOT use `adminPass` here: the module renders it into the
    # world-readable nix store. Instead point `extraConfigFiles` at the
    # agenix secret, which must contain a full ini section:
    #
    #   [admins]
    #   admin = <password-or-hash>
    #
    # (re-encrypt with `agenix -e secrets/couchdb-password.age`)
    extraConfigFiles = [ config.age.secrets.couchdbAdminPassword.path ];

    # Remaining sections from the old local.ini.
    extraConfig = {
      chttpd = {
        require_valid_user = true;
        enable_cors = true;
        max_http_request_size = 4294967296;
      };

      couch_httpd_auth = {
        require_valid_user = true;
      };

      httpd = {
        "WWW-Authenticate" = ''Basic realm="couchdb"'';
        enable_cors = true;
      };

      couchdb = {
        max_document_size = 50000000;
        # Single-node deploy: auto-create _users/_replicator system dbs.
        single_node = true;
      };

      cors = {
        credentials = true;
        origins = "app://obsidian.md,capacitor://localhost,http://localhost";
      };
    };
  };

  # ── Nginx rate-limiting zone (must be at http level) ──────────
  services.nginx.commonHttpConfig = ''
    limit_req_zone $binary_remote_addr zone=${couchRateLimitZone}:10m rate=20r/s;
  '';

  # ── Nginx reverse proxy ───────────────────────────────────────
  services.nginx.virtualHosts."couch.chr.fan" = {
    addSSL = true;
    enableACME = true;

    extraConfig = ''
      limit_req zone=${couchRateLimitZone} burst=30 nodelay;
      client_max_body_size 50m;
    '';

    locations = {
      "/".extraConfig = ''
        proxy_pass http://127.0.0.1:5984;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_request_buffering off;

        # CORS headers (belt-and-suspenders with CouchDB's own CORS)
        add_header Access-Control-Allow-Origin $http_origin always;
        add_header Access-Control-Allow-Credentials true always;
        add_header Access-Control-Allow-Methods "GET,PUT,POST,HEAD,DELETE" always;
        add_header Access-Control-Allow-Headers "accept,authorization,content-type,origin,referer" always;
        add_header Access-Control-Max-Age 3600 always;
        if ($request_method = OPTIONS) {
          return 204;
        }
      '';

      # Block CouchDB admin / introspection endpoints
      "/_utils".extraConfig = "return 403;";
      "/_all_dbs".extraConfig = "return 403;";
      "/_membership".extraConfig = "return 403;";
      "/_node".extraConfig = "return 403;";
      "/_config".extraConfig = "return 403;";
      "/_active_tasks".extraConfig = "return 403;";
      "/_replicator".extraConfig = "return 403;";
    };
  };
}
