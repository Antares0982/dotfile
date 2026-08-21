{
  config,
  pkgs,
  blog,
  ...
}:
let
  site = blog.packages.${pkgs.stdenv.hostPlatform.system}.blog;

  # A page view on a static site cannot be counted in the request path without
  # standing a service in front of every request. nginx is already writing a
  # log line per request, so this rolls those up on a timer instead. See the
  # script's docstring for the format and the WordPress-baseline split.
  viewCounter = pkgs.runCommand "blog-view-counter" { } ''
    mkdir -p $out/bin
    install -m755 ${./blog-view-counter.py} $out/bin/blog-view-counter
    sed -i "1s|.*|#!${pkgs.python3}/bin/python3|" $out/bin/blog-view-counter
  '';

  viewsDir = "/var/lib/blog-views";
  viewsLog = "/var/log/nginx/blog-views.log";
in
{
  services.nginx.commonHttpConfig = ''
    log_format blogviews escape=none
      '$time_iso8601	$remote_addr	$status	$request_uri	$http_user_agent';
  '';

  services.nginx.virtualHosts."blog.chr.fan" = {
    addSSL = true;
    enableACME = true;
    root = "${site}";

    extraConfig = ''
      access_log ${viewsLog} blogviews;

      # Hugo writes every page as <slug>/index.html, so a missing trailing
      # slash still has to resolve.
      location / {
        try_files $uri $uri/ $uri/index.html =404;
      }

      # Fingerprinted CSS and the vendored KaTeX/icon assets never change
      # content under the same store path.
      location ~* ^/(vendor|scss|js)/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
      }
    '';

    locations = {
      # WordPress served the feed at /feed and 301'd to /feed/. The school's
      # RSS aggregator is subscribed to that URL, so both spellings keep
      # working and keep the same redirect.
      "= /feed".return = "301 https://$host/feed/";
      "= /feed/".extraConfig = ''
        default_type application/rss+xml;
        alias ${site}/index.xml;
      '';
      "= /index.xml".extraConfig = ''
        default_type application/rss+xml;
      '';

      # Views recorded since the migration. Each page carries its WordPress
      # total in the HTML and adds this on top.
      "= /api/views.json" = {
        alias = "${viewsDir}/views.json";
        extraConfig = ''
          default_type application/json;
          add_header Cache-Control "public, max-age=300";
          # The file only exists once the timer has run at least once.
          error_page 404 = @noviews;
        '';
      };
      "@noviews".extraConfig = ''
        default_type application/json;
        return 200 '{}';
      '';
    };
  };

  systemd.services.blog-view-counter = {
    description = "Roll up blog page views from the nginx access log";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${viewCounter}/bin/blog-view-counter --log ${viewsLog} --state ${viewsDir}/state.json --out ${viewsDir}/views.json";
      DynamicUser = true;
      StateDirectory = "blog-views";
      # /var/log/nginx is nginx:nginx 0750, so reading the log needs the group.
      SupplementaryGroups = [ "nginx" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ReadOnlyPaths = [ "/var/log/nginx" ];
    };
  };

  systemd.timers.blog-view-counter = {
    description = "Periodically roll up blog page views";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Persistent = true;
    };
  };

  # Without this the dedicated log grows forever; the counter detects the
  # truncation by size and restarts from offset 0.
  services.logrotate.settings.blog-views = {
    files = viewsLog;
    frequency = "weekly";
    rotate = 4;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    su = "nginx nginx";
    postrotate = "[ ! -f /run/nginx/nginx.pid ] || kill -USR1 `cat /run/nginx/nginx.pid`";
  };
}
