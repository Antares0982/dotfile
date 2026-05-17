# {
#   config,
#   lib,
#   pkgs,
#   ...
# }:
# {
#   services.nginx.enable = true;
#   # environment.systemPackages = with pkgs;[
#   #   nginx
#   # ];
#   services.nginx.virtualHosts."gz.chr.fan" = {
#     addSSL = true;
#     # enableACME = true;
#     sslCertificate = "/var/gz.chr.fan_bundle.crt";
#     sslCertificateKey = "/var/gz.chr.fan.key";
#     locations."/" = {
#       root = "/var/www";
#       # tryFiles = "$uri $uri/ /index.php?$args /index.html";
#       tryFiles = "$uri $uri/ /index.html";
#       # extraConfig = ''
#       #   index  index.html index.htm index.php;
#       #   try_files $uri $uri/ /index.php?$args;
#       #   ''
#     };
#   };
# }
