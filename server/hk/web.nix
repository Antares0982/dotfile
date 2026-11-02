{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Remove after nixpkgs includes libxcrypt.
  services.nginx.package = pkgs.nginxStable.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.libxcrypt ];
  });

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [
    80
    443
  ];
}
