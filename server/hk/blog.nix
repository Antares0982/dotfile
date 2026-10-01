{
  lib,
  config,
  pkgs,
  blog,
  ...
}:
let
  site = blog.packages.${pkgs.stdenv.hostPlatform.system}.blog;

in
{
  options.antares.blog.enable = lib.mkEnableOption "blog and metrics";
  config = lib.mkIf (config.antares.blog.enable) {
    assertions = [
      {
        assertion = config.services.nginx.enable;
        message = "Blog requires services.nginx.enable.";
      }
    ];

    services.nginx.virtualHosts."chr.fan" = {
      addSSL = true;
      enableACME = true;
      acmeRoot = null;
      root = "${site}";

      extraConfig = ''

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

      };
    };

    services.nginx.virtualHosts."blog.chr.fan" = {
      addSSL = true;
      enableACME = true;
      acmeRoot = null;
      locations."/".return = "301 https://chr.fan$request_uri";
    };

    services.nginx.virtualHosts."alyr.dev" = {
      addSSL = true;
      enableACME = true;
      acmeRoot = null;
      locations."/".return = "301 https://chr.fan$request_uri";
    };

    services.nginx.virtualHosts."en.chr.fan" = {
      addSSL = true;
      enableACME = true;
      acmeRoot = null;
      locations = {
        "= /2026/01/07/python-json".return = "301 https://chr.fan/en/python-json/$is_args$args";
        "= /2026/01/07/python-json/".return = "301 https://chr.fan/en/python-json/$is_args$args";
        "/".return = "301 https://chr.fan/en$request_uri";
      };
    };

  };
}
