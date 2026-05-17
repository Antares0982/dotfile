{
  nixpkgs,
  nixpkgs-old,
  # nixpkgs-for-chrome,
  agenix,
  lib,
  home-manager,
  myXray,
  wsl,
  vscode-server,
  rust-overlay,
  antares-monitor,
  antares-rpc-client,
  visitor-badge,
  pull-all,
  renewal,
  nixos-raspberrypi,
  linyinfeng-nur,
  ...
}:
let
  xray = myXray;
  _antares-monitor = antares-monitor;
  _antares-rpc-client = antares-rpc-client;
  _visitor-badge = visitor-badge;
  _pull-all = pull-all;
  _renewal = renewal;
  rpi-system = nixos-raspberrypi.lib.nixosSystem;
  nixosSystem = nixpkgs.lib.nixosSystem;
in
(
  currentDevice:
  let
    system = currentDevice.system;
    curNixosSystem = if currentDevice.rpi then rpi-system else nixosSystem;
    nixpkgsToPkgs =
      _nixpkgs:
      (import _nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      }).pkgs;
    myXray = xray.packages.${system}.default;
    xray-sub = xray.packages.${system}.xray_sub;
    antares-monitor = _antares-monitor.packages.${system}.default;
    antares-rpc-client = _antares-rpc-client.packages.${system}.default;
    visitor-badge = _visitor-badge.packages.${system}.default;
    pull-all = _pull-all.packages.${system}.default;
    renewal = _renewal.packages.${system}.default;
    needVSCodeServer = currentDevice.rpi or false;
    pkgs-old = nixpkgsToPkgs nixpkgs-old;
    linyinfeng-nur-packages = linyinfeng-nur.packages.${system};
  in
  curNixosSystem {
    inherit system;
    specialArgs = {
      inherit
        agenix
        currentDevice
        myXray
        xray-sub
        antares-monitor
        antares-rpc-client
        visitor-badge
        pull-all
        renewal
        pkgs-old
        linyinfeng-nur-packages
        ;
    }
    // lib.attrsets.optionalAttrs currentDevice.pc {
      rust-overlay = rust-overlay.overlays.default;
    }
    // lib.attrsets.optionalAttrs currentDevice.rpi {
      inherit nixos-raspberrypi;
    };
    modules = [
      ./configuration.nix
      agenix.nixosModules.default
    ]
    ++ lib.optionals currentDevice.withHm [
      home-manager.nixosModules.home-manager
    ]
    ++ lib.optionals (currentDevice.wsl or false) [
      wsl.nixosModules.wsl
    ]
    ++ lib.optionals needVSCodeServer [
      vscode-server.nixosModules.default
      (
        { config, pkgs, ... }:
        {
          services.vscode-server.enableFHS = true;
        }
      )
    ]
    ++ lib.optionals currentDevice.rpi [
      (
        { ... }:
        {
          imports = with nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base
            raspberry-pi-5.bluetooth
          ];
        }
      )
    ];
  }
)
