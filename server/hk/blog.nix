{
  config,
  pkgs,
  blog,
  ...
}:
let
  site = blog.packages.${pkgs.stdenv.hostPlatform.system}.blog;
  metricsDir = "/var/lib/site-metrics";
  viewsLog = "/var/log/nginx/blog-views.log";
  badgeLog = "/var/log/nginx/visitor-badge.log";
  badgeFallback = pkgs.writeText "visitor-badge-unavailable.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="164" height="20" role="img" aria-label="visitors: unavailable"><title>visitors: unavailable</title><linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="r"><rect width="164" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#r)"><rect width="57" height="20" fill="#595959"/><rect x="57" width="107" height="20" fill="#1283c3"/><rect width="164" height="20" fill="url(#s)"/></g><g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11"><text x="28.5" y="15" fill="#010101" fill-opacity=".3">visitors</text><text x="28.5" y="14">visitors</text><text x="109.5" y="15" fill="#010101" fill-opacity=".3">unavailable</text><text x="109.5" y="14">unavailable</text></g></svg>
  '';
in
{
  services.nginx.enable = true;

  services.nginx.commonHttpConfig = ''
    log_format siteviews escape=none
      '$time_iso8601	$remote_addr	$status	$request_uri	$http_user_agent';
  '';

  services.nginx.virtualHosts."chr.fan" = {
    addSSL = true;
    enableACME = true;
    root = "${site}";

    extraConfig = ''
      access_log ${viewsLog} siteviews;

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

      # The privacy policy is gone: it described cookies only WordPress ever
      # set, and nothing on the static site sets any. It had ~4.7k views, so
      # inbound links land on the home page rather than a 404.
      "= /privacy/".return = "301 /";
      "= /privacy".return = "301 /";

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
        alias = "${metricsDir}/views.json";
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
      "= /api/visitor-badge.svg" = {
        alias = "${metricsDir}/visitor-badge.svg";
        extraConfig = ''
          access_log ${badgeLog} siteviews;
          types { }
          default_type image/svg+xml;
          add_header Cache-Control "no-cache, max-age=0, no-store, s-maxage=0, proxy-revalidate";
          expires -1;
          error_page 404 =200 /api/visitor-badge-unavailable.svg;
        '';
      };
      "= /api/visitor-badge-unavailable.svg" = {
        alias = badgeFallback;
        extraConfig = ''
          internal;
          access_log off;
          types { }
          default_type image/svg+xml;
        '';
      };
    };
  };

  services.nginx.virtualHosts."blog.chr.fan" = {
    addSSL = true;
    enableACME = true;
    locations."/".return = "301 https://chr.fan$request_uri";
  };

  services.nginx.virtualHosts."alyr.dev" = {
    addSSL = true;
    enableACME = true;
    locations."/".return = "301 https://chr.fan$request_uri";
  };

  services.nginx.virtualHosts."en.chr.fan" = {
    addSSL = true;
    enableACME = true;
    locations = {
      "= /2026/01/07/python-json".return = "301 https://chr.fan/en/python-json/$is_args$args";
      "= /2026/01/07/python-json/".return = "301 https://chr.fan/en/python-json/$is_args$args";
      "/".return = "301 https://chr.fan/en$request_uri";
    };
  };
}
