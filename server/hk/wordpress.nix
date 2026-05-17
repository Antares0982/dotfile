{ config, pkgs, ... }:
let
  fetchzip = pkgs.fetchzip;
  wordpress-lang-version-hash = {
    # if a version does not exist, add `wordpress-language-cn` to plugins, and call
    # nix build .\#nixosConfigurations.hk.config.services.wordpress.sites.\"chr.fan\".plugins.wordpress-language-cn
    "6.5.2" = "sha256-6Rj9wnLPOAfQ/1T5qcyHH3XeVHg2hCgSA3wJ9l4pm2A=";
    "6.5.4" = "sha256-ink1l8g28AuQ5x3/wSmA01vIHXdceLh2E8hV68B+kdg=";
    "6.5.5" = "sha256-pTSVAiOcRQP/jheOTJSQ8Qn6QrU1RUUa1Px/jl/trbQ=";
    "6.7" = "sha256-0EZKIW3vXRlINJWV0nwBzbFW3ehwvOjvHXj/UNiYrZw=";
    "6.7.1" = "sha256-VrUw9BjE2PQxwt8tPRo1U9h/RF9eZ38vGuhaid25mnU=";
    "6.7.2" = "sha256-QQKC5W+VNNkATvdZSqGsYDfki2d3tfbReo2cSHp4u6w=";
    "6.8" = "sha256-DRg8sjhfHdyHq3JffX4tYQaatCw81xn5Aqmrkq54x3o=";
    "6.8.1" = "sha256-HvCxo1y9hkkwhxEmXo6x+Phbmo1x5LLlKt1wTCZDmzo=";
    "6.8.2" = "sha256-CoPLD7N8E0j4nxjjMuKiH1m6BYqeH4aM/l2U59I/UFk=";
    "6.8.3" = "sha256-+k8e7oo0h7HxZka+10pJ8o02uOV9q7cEH2fbG0l9Lg4=";
    "6.9.1" = "sha256-3BHPfy225yYvMtsOFn7z0twDCbnVD2Nwh0f4fXUXtOo=";
    "6.9.4" = "sha256-AWnSRrj/fx68CzIItK9KwhDzt6GSGWF/3Wtgd5sz6Bw=";
  };
  wordpress-language-cn = pkgs.stdenv.mkDerivation {
    name = "wordpress-${pkgs.wordpress.version}-language-cn";
    src = pkgs.fetchurl {
      url = "https://cn.wordpress.org/wordpress-${pkgs.wordpress.version}-zh_CN.tar.gz";
      hash = wordpress-lang-version-hash.${pkgs.wordpress.version} or "";
    };
    installPhase = "mkdir -p $out; cp -r ./wp-content/languages/* $out/";
  };
  sakurairo-theme = pkgs.stdenv.mkDerivation {
    name = "sakurairo-theme";
    src = pkgs.fetchFromGitHub {
      owner = "Antares0982";
      repo = "Sakurairo";
      rev = "fae8b45df440d8c35cbc97406838d8f4b26a9b7f";
      # nix build .\#nixosConfigurations.hk.config.services.wordpress.sites.\"chr.fan\".themes.Sakura
      hash = "sha256-stt+Zs1J6jsLse2/l8+1uH8+K8FwZai1aPvXQ/TvBps=";
    };
    installPhase = ''
      runHook preInstall
      cp -R ./. $out
      runHook postInstall
    '';
    postInstall = ''
      # rm -rf $out/manifest/gallary
      # ln -s /var/lib/wordpress/gallary $out/manifest/gallary
    '';
  };
  buildWpPlugin =
    pkgDefine:
    pkgs.stdenvNoCC.mkDerivation {
      inherit (pkgDefine) name;
      src = fetchzip {
        executable = false;
        inherit (pkgDefine) url hash;
      };
      installPhase = ''
        runHook preInstall
        cp -R ./. $out
        runHook postInstall
      '';
    };
  wp-editormd = buildWpPlugin {
    name = "wp-editormd";
    url = "https://downloads.wordpress.org/plugin/wp-editormd.10.2.1.zip";
    hash = "sha256-twEV7eXUI46VJpMuh2NAd9Dglkk3zKlwSQzNcAyLKtY=";
  };
  polylang = buildWpPlugin {
    name = "polylang";
    url = "https://downloads.wordpress.org/plugin/polylang.3.7.5.zip";
    hash = "sha256-ZaQOcyb7Fuz7Csz6YTI8F3WmD0HAxcKA8ArqSxgzTus=";
  };
  # wp-editormd = pkgs.stdenv.mkDerivation {
  #   name = "wp-editormd";
  #   src = pkgs.fetchzip {
  #     executable = false;
  #     url = "https://downloads.wordpress.org/plugin/wp-editormd.10.2.1.zip";
  #     hash = "sha256-twEV7eXUI46VJpMuh2NAd9Dglkk3zKlwSQzNcAyLKtY=";
  #   };
  #   installPhase = ''
  #     runHook preInstall
  #     cp -R ./. $out
  #     runHook postInstall
  #   '';
  # };
  # polylang = pkgs.stdenvNoCC.mkDerivation {
  #   name = "polylang";
  #   src = pkgs.fetchzip {
  #     executable = false;
  #     url = "https://downloads.wordpress.org/plugin/polylang.3.7.5.zip";
  #     hash = "";
  #   };
  #   installPhase = ''
  #     runHook preInstall
  #     cp -R ./. $out
  #     runHook postInstall
  #   '';
  # };
in
{
  services.wordpress.webserver = "nginx";
  services.nginx.package = pkgs.nginx.overrideAttrs (old: rec {
    version = "1.30.1";
    src = pkgs.fetchurl {
      url = "https://nginx.org/download/nginx-${version}.tar.gz";
      hash = "sha256-mXZQANl0iWsxyliC2MJ5zj/n729cb58Kln7X/TQH+cw=";
    };
  });
  services.wordpress.sites."chr.fan" = {
    languages = [ wordpress-language-cn ];
    settings = {
      WPLANG = "zh_CN";
    };
    virtualHost = {
      useACMEHost = "chr.fan";
      # sslServerKey = "/var/chr.fan.key";
      # sslServerCert = "/var/chr.fan_bundle.crt";
    };
    database = {
      user = "wordpress";
      name = "wordpress";
    };
    themes = {
      Sakurairo = sakurairo-theme;
    };
    plugins = {
      inherit (pkgs.wordpressPackages.plugins)
        akismet
        login-lockdown
        wordpress-seo
        wp-statistics
        # wordpress-language-cn
        ;
      inherit wp-editormd polylang;
    };
  };
  services.wordpress.sites."en.chr.fan" = {
    languages = [ ];
    settings = {
      WPLANG = "en_US";
    };
    virtualHost = {
      useACMEHost = "en.chr.fan";
      # sslServerKey = "/var/chr.fan.key";
      # sslServerCert = "/var/chr.fan_bundle.crt";
    };
    database = {
      user = "wordpress";
      name = "wordpress_en";
    };
    themes = {
      Sakurairo = sakurairo-theme;
    };
    plugins = {
      inherit (pkgs.wordpressPackages.plugins)
        akismet
        login-lockdown
        wordpress-seo
        wp-statistics
        # wordpress-language-cn
        ;
      inherit wp-editormd polylang;
    };
  };
  services.nginx.virtualHosts = {
    "chr.fan" = {
      addSSL = true;
      enableACME = true;
      # sslCertificate = "/var/chr.fan_bundle.crt";
      # sslCertificateKey = "/var/chr.fan.key";
    };
    "alyr.dev" =
      let
        confMain = config.services.nginx.virtualHosts."chr.fan";
      in
      {
        addSSL = true;
        enableACME = true;
        inherit (confMain) root locations extraConfig;
      };
    "en.chr.fan" = {
      addSSL = true;
      enableACME = true;
    };
  };
}
