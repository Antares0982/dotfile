inputs: currentDevice:
let
  lib = inputs.lib or inputs.nixpkgs.lib;
  builder =
    if currentDevice.rpi then
      inputs.nixos-raspberrypi.lib.nixosSystem
    else
      inputs.nixpkgs.lib.nixosSystem;
in
builder {
  inherit (currentDevice) system;
  specialArgs = {
    inherit inputs currentDevice;
    agenix = inputs.agenix;
  };
  modules = [
    ./common/cachix.nix
    inputs.agenix.nixosModules.default
  ]
  ++ lib.optionals currentDevice.withHm [ inputs.home-manager.nixosModules.home-manager ]
  ++ lib.optionals currentDevice.wsl [
    ./configuration.nix
    inputs.wsl.nixosModules.wsl
  ]
  ++ lib.optionals currentDevice.rpi [
    inputs.vscode-server.nixosModules.default
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.bluetooth
  ];
}
