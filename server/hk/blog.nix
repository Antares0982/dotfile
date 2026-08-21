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
      # Three slugs were Chinese under WordPress and are ASCII now. Those URLs
      # carry about 18k views of history and are what search results point at,
      # so they redirect permanently rather than 404.
      #
      # The literal UTF-8 here matches both encodings the wild uses -- lowercase
      # %e8%b8%a9 from WordPress's own links, uppercase from everything since --
      # because nginx decodes the URI before it matches locations.
      #
      # Both spellings are listed because the slash-adding redirect nginx does
      # for directories cannot fire here: these directories no longer exist, so
      # a slashless request would fall through to try_files and 404. WordPress
      # canonicalised the slashless form too.
      "= /arch踩坑记录/".return = "301 /arch-pitfalls/";
      "= /arch踩坑记录".return = "301 /arch-pitfalls/";
      "= /words/万事顺利/".return = "301 /words/all-going-well/";
      "= /words/万事顺利".return = "301 /words/all-going-well/";
      "= /words/2022黄昏/".return = "301 /words/2022-dusk/";
      "= /words/2022黄昏".return = "301 /words/2022-dusk/";

      "= /feed".return = "301 https://$host/feed/";
      # `alias` cannot serve this: the location ends in a slash, so nginx
      # treats the request as a directory and appends the index file to the
      # aliased path, yielding ".../index.xmlindex.html". Rewriting hands the
      # request to the /index.xml location instead.
      "= /feed/".extraConfig = ''
        rewrite ^ /index.xml last;
      '';
      # `.xml` is already in mime.types as text/xml, so default_type alone is
      # ignored; the empty types block clears that mapping so it applies.
      "= /index.xml".extraConfig = ''
        types { }
        default_type application/rss+xml;
        charset utf-8;
      '';

      # Views recorded since the migration. Each page carries its WordPress
      # total in the HTML and adds this on top.
      "= /api/views.json" = {
        alias = "${viewsDir}/views.json";
        extraConfig = ''
          types { }
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

  users.users.blog-views = {
    isSystemUser = true;
    group = "blog-views";
    description = "Blog view-count aggregator";
  };
  users.groups.blog-views = { };

  systemd.services.blog-view-counter = {
    description = "Roll up blog page views from the nginx access log";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${viewCounter}/bin/blog-view-counter --log ${viewsLog} --state ${viewsDir}/state.json --out ${viewsDir}/views.json";
      # Not DynamicUser: that puts the state under /var/lib/private, which is
      # 0700 root, so nginx cannot traverse it to reach views.json.
      User = "blog-views";
      Group = "blog-views";
      StateDirectory = "blog-views";
      StateDirectoryMode = "0755";
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

  # No logrotate entry here on purpose: the nginx module already rotates
  # /var/log/nginx/*.log, which this log matches, and logrotate refuses to
  # start at all on a duplicate entry. The counter restarts from offset 0 when
  # it sees the file has shrunk, so rotation needs no cooperation from it.
}
