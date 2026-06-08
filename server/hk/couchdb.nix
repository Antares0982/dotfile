{
  config,
  lib,
  pkgs,
  ...
}:

let
  couchdbStateDir = "/var/lib/couchdb";
  couchdbPkg = pkgs.couchdb3;
  couchRateLimitZone = "couch_zone";
in
{
  # ── CouchDB user ──────────────────────────────────────────────
  users.users.couchdb = {
    isSystemUser = true;
    group = "couchdb";
    home = couchdbStateDir;
    createHome = true;
  };
  users.groups.couchdb = { };

  # ── State directories ─────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d ${couchdbStateDir} 0750 couchdb couchdb - -"
    "d ${couchdbStateDir}/data 0750 couchdb couchdb - -"
    "d ${couchdbStateDir}/etc 0750 couchdb couchdb - -"
    "d ${couchdbStateDir}/view_index 0750 couchdb couchdb - -"
  ];

  # ── CouchDB systemd service ───────────────────────────────────
  systemd.services.couchdb = {
    description = "CouchDB for Obsidian LiveSync";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
        ADMIN_PASS=$(head -n1 "${config.age.secrets.couchdbAdminPassword.path}")
        umask 027
        cat > ${couchdbStateDir}/etc/local.ini <<CEOF
      ; Managed by NixOS — do not edit manually

      [admins]
      admin = $ADMIN_PASS

      [chttpd]
      bind_address = 127.0.0.1
      port = 5984
      require_valid_user = true
      enable_cors = true
      max_http_request_size = 4294967296

      [couch_httpd_auth]
      require_valid_user = true

      [httpd]
      WWW-Authenticate = Basic realm="couchdb"
      enable_cors = true

      [couchdb]
      max_document_size = 50000000

      [cors]
      credentials = true
      origins = app://obsidian.md,capacitor://localhost,http://localhost
      CEOF
        chown couchdb:couchdb ${couchdbStateDir}/etc/local.ini
    '';

    serviceConfig = {
      User = "couchdb";
      Group = "couchdb";
      ExecStart = "${couchdbPkg}/bin/couchdb";
      Environment = [
        "COUCHDB_DATA_DIR=${couchdbStateDir}/data"
        "COUCHDB_CONFIG_DIR=${couchdbStateDir}/etc"
        "COUCHDB_VIEW_INDEX_DIR=${couchdbStateDir}/view_index"
        "HOME=${couchdbStateDir}"
      ];
      Restart = "always";
      RestartSec = 5;

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = couchdbStateDir;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      MemoryDenyWriteExecute = false; # Erlang needs JIT
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
